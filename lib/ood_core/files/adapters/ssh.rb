# frozen_string_literal: true

require 'ood_core/job/adapters/helper'
require 'fileutils'
require 'open3'
require 'timeout'
require 'date'

module OodCore
  module Files
    module Adapters
      # An adapter that provides access to files over SSH.
      class Ssh < Adapter
        UNESCAPES = {
          'a' => "\x07", 'b' => "\x08", 't' => "\x09",
          'n' => "\x0a", 'v' => "\x0b", 'f' => "\x0c",
          'r' => "\x0d", 'e' => "\x1b", '\\\\' => "\x5c",
          '"' => "\x22", "'" => "\x27"
        }.freeze

        # After the permissions, ls prints . for a security context, + for other access methods such as ACLs, or
        # nothing. uutils coreutils 0.8.0 (Ubuntu 26.04) does not print a space after . or +.
        LS_REGEX = Regexp.new('^(?<type>[ld-])(?<perms>\S{9})(?<acl>[.+]?)\s*(?<nlinks>\d+)\s+(?<user>\S+)\s+(?<group>\S+)\s+(?<size>\d+)\s+(?<time>\S+)\s+"(?<name>.+)"$')
        PROGRESS_REGEX = /\s*\d+\s+(?<progress>\d+)%/.freeze
        # Exit status of the shell when a command is not installed.
        COMMAND_NOT_FOUND = 127
        # Bytes read at a time from an IO that is written to the cluster.
        WRITE_CHUNK_SIZE = 128 * 1024
        # Bits of a file mode for the file type, and the type of directories.
        S_IFMT = 0o170000
        S_IFDIR = 0o040000

        attr_reader :host, :bin_overrides, :strict_host_checking, :ssh_port, :dataroot_timeout, :dataroot_retry_after,
                    :cluster_id

        # @param host [#to_s] The SSH host to connect to (required)
        # @param bin_overrides [Hash] Overrides for binaries such as ssh and rsync
        # @param strict_host_checking [Boolean] Set to false to disable strict host checking
        # @param ssh_port [Integer, nil] The SSH port of the host, defaults to OOD_SSH_PORT or ssh_config
        # @param dataroot_timeout [#to_i] Seconds to wait for the cluster when looking up the dataroot
        # @param dataroot_retry_after [#to_i] Seconds to wait before retrying a failed dataroot lookup
        # @param cluster_id [#to_s] The cluster this adapter is for
        def initialize(host: nil, bin_overrides: {}, strict_host_checking: true, ssh_port: nil,
                       dataroot_timeout: 20, dataroot_retry_after: 300, cluster_id: nil)
          raise ArgumentError, "No host specified for the files adapter of cluster #{cluster_id}" if host.to_s.empty?

          @host = host
          @bin_overrides = bin_overrides
          @strict_host_checking = strict_host_checking
          @ssh_port = ssh_port
          @dataroot_timeout = dataroot_timeout.to_i
          @dataroot_retry_after = dataroot_retry_after.to_i
          @cluster_id = cluster_id
          super
        end

        class << self
          # Home directories on the clusters, or the most recent failure to look one up, by cluster and host.
          # This is per process, as new adapters are created for every use.
          def home_directories
            @home_directories ||= {}
          end

          def clear_dataroot_cache
            home_directories.clear
          end
        end

        # Runs cmd on the cluster over SSH, returning its stdout, stderr and status like Open3.capture3.
        # @param binmode [Boolean] pass stdin and output as bytes without encoding conversion, only without a timeout
        def call(cmd, *args, stdin: '', timeout: 0, binmode: false)
          cmd, args = ssh_wrap(cmd, args.map(&:to_s))
          if timeout > 0
            capture3_with_timeout(cmd, *args, stdin_data: stdin.to_s, timeout: timeout)
          else
            Open3.capture3(cmd, *args, stdin_data: stdin.to_s, binmode: binmode)
          end
        end

        # Dataroot for the cluster, where interactive app sessions (and more) will be staged.
        # @raise [OodCore::FilesAdapterError] if the home directory on the cluster could not be determined
        def dataroot
          # TODO: Avoid duplicating this logic from ood_appkit?
          home_directory.join(ENV['OOD_PORTAL'] || 'ondemand', 'data', ENV.fetch('APP_TOKEN', 'sys/dashboard'))
        end

        # The user's home directory on the cluster. Home directories are looked up once per process, and failed
        # lookups are retried only after dataroot_retry_after seconds, so that a failing cluster is not contacted
        # again every time the dataroot is needed.
        # @raise [OodCore::FilesAdapterError] if the home directory could not be determined
        def home_directory
          key = [cluster_id, host]
          entry = self.class.home_directories[key]
          if entry.nil? || (entry[:error] && entry[:retry_at] <= monotonic_now)
            entry = self.class.home_directories[key] = begin
              { home: look_up_home_directory }
            rescue StandardError => e
              { error: "Could not access cluster #{cluster_id}: #{e.message}",
                retry_at: monotonic_now + dataroot_retry_after }
            end
          end
          return entry[:home] if entry[:home]

          raise OodCore::FilesAdapterError,
                "#{entry[:error]} (will retry in #{(entry[:retry_at] - monotonic_now).ceil}s)"
        end

        def directory?(path)
          (stat(path) & S_IFMT) == S_IFDIR
        end

        def exist?(path)
          stat(path)
          true
        rescue StandardError
          false
        end

        def ls(path)
          # Due to lack of better alternatives, parse the output of ls.
          # Follow symlinks to show info about target in the file browser instead of symlink.
          # --block-size=1 prints sizes in bytes, even if BLOCK_SIZE or LS_BLOCK_SIZE are set in the environment.
          args = ['-l', '--almost-all', '--quoting-style=c', '--time-style=+%Y-%m-%dT%H:%M:%S%z', '--dereference',
                  '--block-size=1', Shellwords.escape(path)]

          stdout, stderr, status = call('ls', *args)
          # ls exits with 1 if only some entries could not be read, so list whatever it managed to output.
          # Anything else means that the directory itself could not be listed.
          unless status.success? || status.exitstatus == 1
            raise StandardError, "Could not list #{path}: #{failure_reason('ls', status, stderr)}"
          end

          stdout.lines.drop(1).map do |line|
            match = line.match(LS_REGEX)
            # Ignore sockets, named pipes and other special files.
            next if match.nil?

            escaped_name, size, type, time, user, perms = match.named_captures.values_at('name', 'size', 'type', 'time',
                                                                                         'user', 'perms')
            name = unescape(escaped_name).force_encoding('utf-8')
            {
              name:      name,
              size:      type == 'd' ? nil : size.to_i,
              directory: type == 'd',
              date:      DateTime.parse(time).to_time.to_i,
              owner:     user,
              mode:      parse_perms(perms)
            }
          end.compact
        end

        # Files to include when downloading path as a zip, like for local directories: path itself is followed if it
        # is a symlink (-H), and symlinks to files are included (-xtype), but symlinks to directories are not followed.
        def ls_recursive(path)
          stdout, stderr, status = call('find', '-H', Shellwords.escape(path), '-xtype', 'f', '-print0')
          raise StandardError, "Could not list files in #{path}: #{failure_reason('find', status, stderr)}" unless status.success?

          # Split the raw bytes, as file names do not have to be valid UTF-8.
          stdout.b.split("\0").map { |file| file.force_encoding(Encoding::UTF_8) }
        end

        def editable?(path)
          _, _, status = call('test', '-f', Shellwords.escape(path), '-a', '-r', Shellwords.escape(path), '-a', '-w',
                              Shellwords.escape(path))
          status.success?
        end

        # Whether path can be read, following symlinks.
        # @raise [StandardError] if this could not be checked, e.g. because the cluster could not be reached
        def readable?(path)
          _, stderr, status = call('test', '-r', Shellwords.escape(path))
          # test exits with 1 if path is not readable or does not exist
          return status.success? if [0, 1].include?(status.exitstatus)

          raise StandardError, "Could not check #{path}: #{failure_reason('test', status, stderr)}"
        end

        def read(path, &_block)
          if block_given?
            call_popen('cat', Shellwords.escape(path)) do |o|
              while (data = o.read(32_768))
                yield data
              end
            end
          else
            stdout, stderr, status = call('cat', Shellwords.escape(path))
            unless status.success?
              err = failure_reason('cat', status, stdout, stderr)
              raise StandardError, "Could not read file #{path}: #{err}"
            end
            stdout
          end
        end

        def touch(path)
          stdout, stderr, status = call('touch', Shellwords.escape(path))
          return if status.success?

          err = failure_reason('touch', status, stdout, stderr)
          raise StandardError, "Could not touch #{path}: #{err}"
        end

        def mkdir(path)
          stdout, stderr, status = call('mkdir', '-p', Shellwords.escape(path))
          return if status.success?

          err = failure_reason('mkdir', status, stdout, stderr)
          raise StandardError, "Could not create directory #{path}: #{err}"
        end

        # Writes content to path with dd, which leaves the permissions and group of an existing file as they are.
        # Missing parent directories are created in the same connection.
        # An IO is streamed to the cluster, yielding the percentage written so far if its size is known.
        def write(path, content, &block)
          return write_io(path, content, &block) if content.respond_to?(:read)

          stdout, stderr, status = call(*write_command(path), stdin: content, binmode: true)
          return if status.success?

          err = failure_reason('dd', status, stdout, stderr)
          raise StandardError, "Could not write #{path}: #{err}"
        end

        def size(path)
          stdout, stderr, status = call('stat', '--dereference', '--format', '%s', Shellwords.escape(path))
          raise StandardError, "Could not stat #{path}: #{failure_reason('stat', status, stderr)}" unless status.success?

          stdout.to_i
        end

        def mime_type(path)
          stdout, stderr, status = call('file', '--dereference', '-Eb', '--mime-type', Shellwords.escape(path))
          unless status.success?
            err = failure_reason('file', status, stdout, stderr)
            raise StandardError, "Could not check file type of #{path}: #{err}"
          end

          stdout.strip
        end

        # Total size in bytes of the directory and everything in it, following symlinks.
        # @raise [Timeout::Error] if the size could not be determined within the timeout
        # @raise [OodCore::FilesAdapterError] if the size could not be determined
        def directory_size(path, timeout:)
          # Example output from: du -bLs $path
          #
          #    496184  $path
          #
          o, e, s = call('timeout', "#{timeout}s", 'du', '-bLs', Shellwords.escape(path.to_s))
          raise Timeout::Error, "Could not determine size of #{path} within #{timeout}s" if s.exitstatus == 124

          size = o.split.first.to_s
          # du exits with 1 if it encounters e.g. a broken symlink, but the size may still be valid.
          unless (s.success? || s.exitstatus == 1) && size.to_i.to_s == size
            raise OodCore::FilesAdapterError, failure_reason('du', s, "du exited with status #{s.exitstatus}: #{e.strip}")
          end

          size.to_i
        end

        # Moves src on src_fs to dst on dest_fs: with mv within the cluster, or rsync to or from the local filesystem.
        def move_with_progress(src_fs, dest_fs, src, dst, &block)
          # use rsync for local<->cluster and mv for cluster<->cluster
          from_cluster = this_cluster?(src_fs)
          to_cluster = this_cluster?(dest_fs)
          within_cluster = from_cluster && to_cluster
          if within_cluster
            mv(src, dst, &block)
          else
            rsync_with_progress(src, dst, src_fs: from_cluster && host, dest_fs: to_cluster && host, move: true, &block)
          end
        end

        # Copies src on src_fs to dst on dest_fs with rsync, yielding the percentage copied so far.
        def copy_with_progress(src_fs, dest_fs, src, dst, &block)
          # use rsync for local<->cluster, and rsync on the cluster for cluster<->cluster
          from_cluster = this_cluster?(src_fs)
          to_cluster = this_cluster?(dest_fs)
          within_cluster = from_cluster && to_cluster
          if within_cluster
            cp(src, dst, &block)
          else
            rsync_with_progress(src, dst, src_fs: from_cluster && host, dest_fs: to_cluster && host, move: false,
                                          &block)
          end
        end

        # Yields the percentage of files and directories removed so far, whenever it changes.
        def remove_with_progress(path)
          escaped = Shellwords.escape(path)
          removed = 0
          percent = 0
          # First count the files and directories, printing a character for each so that newlines in file names do
          # not matter, then remove them in the same call. -v prints a line for every file and directory removed.
          call_popen('find', escaped, '-printf', '.', '|', 'wc', '-c', ';', 'rm', '-rv', escaped) do |o|
            total = o.gets.to_i
            o.each_line do
              removed += 1
              next unless block_given? && total.positive?

              new_percent = [100 * removed / total, 100].min
              yield new_percent if new_percent != percent
              percent = new_percent
            end
          end
        rescue StandardError => e
          raise StandardError, "Could not remove #{path}: #{e.message}"
        end

        private

        # Helper fuction for unescaping file names from ls that were escaped with --quoting-style=c
        # Modified from https://stackoverflow.com/questions/8639642/best-way-to-escape-and-unescape-strings-in-ruby
        def unescape(str)
          str.b.gsub(/\\(?:([#{UNESCAPES.keys.join}])|(\d{3}))/) do
            if Regexp.last_match(1)
              Regexp.last_match(1) == '\\' ? '\\' : UNESCAPES[Regexp.last_match(1)]
            elsif Regexp.last_match(2) # escape \000
              [Regexp.last_match(2).to_i(8)].pack('c')
            end
          end
        end

        # The ssh binary and options used for all connections to the host.
        def ssh_command
          ssh = OodCore::Job::Adapters::Helper.bin_path('ssh', nil, bin_overrides)
          # Same options as OodCore::Job::Adapters::Helper.ssh_wrap
          check_host = strict_host_checking ? 'yes' : 'no'
          args = OodCore::Job::Adapters::Helper.ssh_port_args(ssh_port) + ['-o', 'BatchMode=yes',
                  '-o', 'UserKnownHostsFile=/dev/null', '-o', "StrictHostKeyChecking=#{check_host}"]
          [ssh, args]
        end

        # Wraps a command in ssh. Unlike OodCore::Job::Adapters::Helper.ssh_wrap, arguments are passed
        # to the remote shell as is, so callers are responsible for escaping them. This allows
        # using shell features such as redirection and variable expansion.
        def ssh_wrap(cmd, args)
          ssh, ssh_args = ssh_command
          [ssh, ssh_args + [host, cmd] + args]
        end

        # Runs rsync locally, connecting to the cluster with the same ssh command and options as #call. Like with #call,
        # paths on the cluster are passed to the shell there as they are, so callers are responsible for escaping them.
        def rsync_popen(*args, &block)
          ssh_cmd, ssh_args = ssh_command
          rsync = OodCore::Job::Adapters::Helper.bin_path('rsync', '', bin_overrides)
          args = ['-e', "#{Shellwords.escape(ssh_cmd)} #{ssh_args.join(' ')}"] + args.map(&:to_s)
          # RSYNC_OLD_ARGS stops rsync >= 3.2.4 from escaping the paths again, which would leave wildcards for the
          # remote shell to expand. It also turns off the check of rsync >= 3.2.5 that the files it receives match the
          # requested paths, which rejects names with both backslashes and wildcards.
          # RSYNC_PROTECT_ARGS=0 keeps older versions from sending the paths without the remote shell (-s) if that is
          # enabled in the environment, as the rsync on the cluster would then expand wildcards in them.
          env = { 'RSYNC_OLD_ARGS' => '1', 'RSYNC_PROTECT_ARGS' => '0' }
          # rsync exits with the same status as the shell if rsync is not installed on the cluster.
          popen('rsync', rsync, args, label: 'rsync', env: env, &block)
        end

        # Transfers src to dst with rsync, where either side can be on the cluster, yielding the percentage done so far.
        # Creates missing parent directories of dst, and with move: true removes the source afterwards.
        def rsync_with_progress(src, dst, src_fs: nil, dest_fs: nil, move: false)
          full_src = src
          full_dst = dst
          # Paths on the cluster go through the shell there (see #rsync_popen).
          full_src = "#{src_fs}:#{Shellwords.escape(src)}" if src_fs
          full_dst = "#{dest_fs}:#{Shellwords.escape(dst)}" if dest_fs
          dir = src_fs ? directory?(src) : File.directory?(src)
          full_src = "#{full_src}/" if dir
          # --ignore-times always transfers files, instead of skipping existing files with the same size and mtime.
          args = ['-a', '--ignore-times', '--info=all0,progress2']
          args << '--remove-source-files' if move
          # rsync does not create missing parent directories of the destination. On the cluster, create them in the
          # same connection, before starting rsync there.
          if dest_fs
            args << "--rsync-path=mkdir -p #{Shellwords.escape(File.dirname(dst))} && rsync"
          else
            FileUtils.mkdir_p(File.dirname(dst))
          end
          rsync_popen(*args, full_src, full_dst) do |o|
            each_rsync_progress(o) { |progress| yield progress if block_given? }
          end
          # --remove-source-files only removes files, so remove the directories left behind.
          remove_empty_directories(src, remote: src_fs) if move && dir
        end

        # Removes the directory and its subdirectories as long as they are empty.
        def remove_empty_directories(dir, remote: false)
          _, stderr, status = if remote
                                call('find', Shellwords.escape(dir), '-type', 'd', '-empty', '-delete')
                              else
                                Open3.capture3('find', dir, '-type', 'd', '-empty', '-delete')
                              end
          raise StandardError, "Could not remove #{dir}: #{failure_reason('find', status, stderr)}" unless status.success?
        end

        # Streams io to dd on the cluster, yielding the percentage written whenever it changes, if the size of io is
        # known.
        def write_io(path, io)
          total = io.respond_to?(:size) ? io.size.to_i : 0
          percent = 0
          call_popen_write(*write_command(path), stdin: io, name: 'dd') do |written|
            next unless block_given? && total.positive?

            new_percent = [100 * written / total, 100].min
            yield new_percent if new_percent != percent
            percent = new_percent
          end
        rescue StandardError => e
          raise StandardError, "Could not write #{path}: #{e.message}"
        end

        # The command for #write: dd to path, after creating its parent directories.
        # Known limitation: uutils dd (rust-coreutils, the default coreutils on Ubuntu 26.04) refuses operands that are
        # not valid UTF-8, so files whose paths are not valid UTF-8 cannot be written on those clusters.
        def write_command(path)
          ['mkdir', '-p', Shellwords.escape(File.dirname(path)), '&&',
           'dd', "of=#{Shellwords.escape(path)}", 'bs=128K', 'status=none']
        end

        # Runs cmd on the cluster with io as its input, yielding the number of bytes written to it after each chunk.
        # @param name [String] the command as it is called on the cluster, to tell if it is not installed there
        # @raise [StandardError] if the command fails, with its error output, or saying that name is not installed
        def call_popen_write(cmd, *args, stdin:, name: cmd)
          wrapped_cmd, wrapped_args = ssh_wrap(cmd, args.map(&:to_s))
          Open3.popen3(wrapped_cmd, *wrapped_args) do |i, o, e, t|
            # Write bytes as they are, even if Encoding.default_internal is set, as it is in Rails.
            i.binmode
            out_reader = read_in_background(o)
            err_reader = read_in_background(e)
            written = 0
            begin
              while (chunk = stdin.read(WRITE_CHUNK_SIZE))
                i.write(chunk)
                written += chunk.bytesize
                yield written
              end
            rescue Errno::EPIPE
              # The command exited before reading all of its input, which its status and error output explain.
            end
            i.close

            status = t.value
            next if status.success?

            err = failure_reason(name, status, err_reader.value, out_reader.value)
            raise StandardError, err.empty? ? "Command exited with status #{status.exitstatus}" : err
          end
        end

        # Runs cmd on the cluster, yielding its output as it is produced.
        def call_popen(cmd, *args, stdin: nil, &block)
          wrapped_cmd, wrapped_args = ssh_wrap(cmd, args.map(&:to_s))
          # Commands can be chained in the remote shell, so the status is not necessarily from cmd.
          popen(cmd, wrapped_cmd, wrapped_args, label: 'Command', stdin: stdin, &block)
        end

        # capture3 (from Open3), but with added support for timeouts.
        # Timeout::timeout is explicitly not used here as it does not work correctly with Open3.
        # See https://bugs.ruby-lang.org/issues/4681
        # This method below is modified version of the linked GitHub gist (capture3 instead of capture2e).
        # @raise [Timeout::Error] if the command was terminated because it did not finish within the timeout
        def capture3_with_timeout(*args, **kwargs)
          timeout = kwargs.fetch(:timeout, 0)
          # Spawn a new pgroup to be able to terminate all children.
          # stdin_data only exists for capture3, not popen3, handle manually.
          Open3.popen3(*args, **kwargs.except(:timeout, :stdin_data).merge({pgroup: true})) do |stdin, stdout, stderr, wait_thr|
            deadline = monotonic_now + timeout if timeout > 0
            stdin.write(kwargs[:stdin_data]) if kwargs[:stdin_data]
            stdin.close
            output = { stdout => String.new, stderr => String.new }
            pipes = [stdout, stderr]
            # Read stdout and stderr until both reach EOF, the process has exited and its output has been
            # drained, or the timeout is reached.
            until pipes.empty? || remaining_time(deadline)&.zero?
              exited = !wait_thr.alive?
              # Wait at most 0.1 seconds at a time, as select does not return when the process exits.
              ready, = IO.select(pipes, nil, nil, exited ? 0 : [remaining_time(deadline), 0.1].compact.min)
              break if ready.nil? && exited
              next if ready.nil?

              ready.each do |pipe|
                output[pipe] << pipe.read_nonblock(4096)
              rescue IO::WaitReadable
              rescue EOFError
                pipes.delete(pipe)
              end
            end
            # Terminate the whole process group if it is still running after the timeout.
            unless wait_thr.join(remaining_time(deadline))
              begin
                Process.kill("-TERM", wait_thr.pid)
              rescue Errno::ESRCH
              end
              raise Timeout::Error, "timed out after #{timeout.round}s"
            end
            [output[stdout], output[stderr], wait_thr.value]
          end
        end

        # Parses permissions in rwxrwxrwx format into octal mode.
        # Ignores sticky, setuid and setgid bits.
        def parse_perms(perms)
          return 0 unless perms.length == 9

          perms.chars.each_slice(3).to_a.map do |r, w, x|
            r_ = r == 'r' ? 4 : 0
            w_ = w == 'w' ? 2 : 0
            x_ = ['x', 's', 't'].include?(x) ? 1 : 0
            r_ + w_ + x_
          end.map(&:to_s).join.to_i(8)
        end

        def mv(src, dst)
          # -T renames src to dst, instead of moving it into dst if that is an existing directory.
          stdout, stderr, status = call('mv', '-T', Shellwords.escape(src), Shellwords.escape(dst))
          return if status.success?

          err = failure_reason('mv', status, stdout, stderr)
          raise StandardError, "Could not move #{src} to #{dst}: #{err}"
        end

        # Copies within the cluster with rsync, yielding the percentage copied so far.
        def cp(src, dst)
          src = Pathname.new(src).cleanpath.to_s
          dst = Pathname.new(dst).cleanpath.to_s
          if File.basename(src) == File.basename(dst)
            # Copying into the parent directory of dst keeps the name, so there is no need to check whether src is a
            # directory first. Paths in the copy then start with the name.
            from = src
            to = "#{File.dirname(dst)}/"
            root = File.basename(src)
          else
            # The trailing slash copies the contents of the directory to dst, instead of into dst/<name>.
            # Symlinks to directories are copied as symlinks, like cp -r does.
            from = real_directory?(src) ? "#{src}/" : src
            to = dst
          end
          # -rlD copies like cp -r: recursively, and symlinks and special files as they are.
          args = ['-rlD', '--info=all0,progress2']
          # When copying a directory into itself, leave the destination out of the copy, so that the directory is
          # copied as it was before the copy started, like local copies in the dashboard. cp refuses to do this.
          dst_in_src = relative_path_inside(src, dst)
          args << "--exclude=/#{rsync_literal([root, dst_in_src].compact.join('/'))}" if dst_in_src
          args << from << to
          call_popen('rsync', *args.map { |arg| Shellwords.escape(arg) }) do |o|
            each_rsync_progress(o) { |progress| yield progress if block_given? }
          end
        rescue StandardError => e
          raise StandardError, "Could not copy #{src} to #{dst}: #{e.message}"
        end

        def rm(path)
          stdout, stderr, status = call('rm', '-r', Shellwords.escape(path))
          return if status.success?

          err = failure_reason('rm', status, stdout, stderr)
          raise StandardError, "Could not remove #{path}: #{err}"
        end

        # Runs cmd with args, yielding its stdout while it runs.
        # @param name [String] the command as it is called on the cluster, to tell if it is not installed there
        # @param label [String] what exited, for errors
        # @param env [Hash] environment variables to set for the command
        # @raise [StandardError] if the command fails, with its error output, or saying that name is not installed
        def popen(name, cmd, args, label:, stdin: nil, env: {})
          Open3.popen3(env, cmd, *args) do |i, o, e, t|
            i.write(stdin) if stdin
            i.close

            err_reader = read_in_background(e)

            yield o

            o.close
            status = t.value
            next if status.success?

            err = err_reader.value.to_s.strip
            raise StandardError, failure_reason(name, status, "#{label} exited with status #{status.exitstatus}\n#{err}")
          end
        end

        # Reads io to its end in a thread, whose value is what was read.
        # Open3 closes io when its block exits, which can be while the thread is still reading: when the output is
        # not needed after a command succeeds, or a process the command left running keeps it open. The thread then
        # ends with an IOError that nothing needs.
        def read_in_background(io)
          Thread.new { io.read }.tap { |thread| thread.report_on_exception = false }
        end

        # Whether fs is this adapter's cluster, rather than the local file system.
        # @raise [StandardError] if fs is another cluster
        def this_cluster?(fs)
          return false unless fs.respond_to?(:file_adapter)
          return true if fs.id.to_s == cluster_id.to_s

          raise StandardError, "Transfers between different clusters are not supported (#{fs.id} and #{cluster_id})"
        end

        # The path relative to dir if it is inside dir, otherwise nil.
        def relative_path_inside(dir, path)
          relative = Pathname.new(path).cleanpath.relative_path_from(Pathname.new(dir).cleanpath)
          relative.to_s unless relative.to_s == '.' || relative.each_filename.first == '..'
        end

        # The mode of path, following symlinks.
        def stat(path)
          # %f is the raw mode in hex. The file type from %F would be translated in non-English locales.
          stdout, stderr, status = call('stat', '--dereference', '--format', '%f', Shellwords.escape(path))
          # stat exits with 1 both for missing paths and e.g. denied permissions, so show its reason.
          raise StandardError, "Could not stat #{path}: #{failure_reason('stat', status, stderr)}" unless status.success?

          stdout.to_i(16)
        end

        # Whether path is a directory itself, rather than a symlink to one.
        def real_directory?(path)
          stdout, _, status = call('stat', '--format', '%f', Shellwords.escape(path))
          status.success? && (stdout.to_i(16) & S_IFMT) == S_IFDIR
        end

        # Yields each percentage in the output of rsync --info=progress2.
        def each_rsync_progress(output)
          output.each_line("\r") do |line|
            match = line.match(PROGRESS_REGEX)
            yield match[:progress].to_i if match
          end
        end

        # Escapes a path to match it literally in an rsync filter rule.
        # Backslashes are only escape characters in patterns that contain wildcards.
        def rsync_literal(path)
          path.match?(/[*?\[]/) ? path.gsub(/[*?\[\\]/) { |char| "\\#{char}" } : path
        end

        # A short reason for a failed command: that it is not installed on the cluster, or the first output.
        # Output that is not valid UTF-8, e.g. naming such files, is scrubbed.
        def failure_reason(cmd, status, *outputs)
          return "#{cmd} is not installed on cluster #{cluster_id}" if status.exitstatus == COMMAND_NOT_FOUND

          outputs.map { |output| utf8(output).scrub.strip }.find { |output| !output.empty? }.to_s
        end

        # Looks up $HOME on the cluster.
        # @raise [OodCore::FilesAdapterError] with a short reason if the lookup fails or the output is not a path
        def look_up_home_directory
          stdout, stderr, status = begin
            call('echo', '$HOME', timeout: dataroot_timeout)
          rescue Timeout::Error => e
            raise OodCore::FilesAdapterError, e.message
          end
          unless status.success?
            # The last line has the actual error, e.g. "ssh: connect to host ...: Connection refused".
            reason = utf8(stderr).scrub.lines.map(&:strip).reject(&:empty?).last
            raise OodCore::FilesAdapterError, reason || "ssh exited with status #{status.exitstatus.inspect}"
          end

          home = utf8(stdout).chomp
          # e.g. empty if $HOME is not set, or with extra output from the user's shell startup files
          unless home.valid_encoding? && home.start_with?('/') && !home.include?("\n")
            raise OodCore::FilesAdapterError,
                  "unexpected output when looking up the home directory: #{home[0, 100].inspect}"
          end

          Pathname.new(home)
        end

        def utf8(str)
          str.to_s.dup.force_encoding(Encoding::UTF_8)
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # Seconds left until the deadline (from monotonic_now), at least 0, or nil if there is no deadline.
        def remaining_time(deadline)
          return nil if deadline.nil?

          [deadline - monotonic_now, 0].max
        end
      end
    end
  end
end
