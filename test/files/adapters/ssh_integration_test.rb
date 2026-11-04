require_relative 'ssh_test_helper'
require 'tmpdir'
require 'tempfile'

# Runs the ssh files adapter against the local file system through a fake ssh (see test/fixtures/scripts/fake_ssh),
# so that the real commands, shell escaping and rsync invocations are exercised without an ssh server.
class SshIntegrationTest < Minitest::Test
  include TestHelper
  include SshTestHelper

  FILE_NAMES = [
    'plain.txt',
    'with space.txt',
    %q(it's "odd".txt),
    '$HOME `id` $(id).txt',
    'semi;colon & pipe|*?.txt',
    'ünïcödé.txt',
    "new\nline.txt",
    "tab\tand\\backslash.txt",
    '-leading-dash.txt',
    '.hidden'
  ].freeze

  # File names are bytes, so these are all valid names on the cluster even though none of them are valid UTF-8.
  INVALID_UTF8_NAMES = [
    "\xFF\xFE lone bytes.txt",
    "caf\xE9 latin-1.txt",
    "\xC3( bad continuation.txt",
    "\xC0\xAF overlong slash.txt",
    "\xC0\x80 overlong nul.txt",
    "\xED\xA0\x80\xED\xB0\x80 surrogates.txt",
    "\xF4\x90\x80\x80 above max.txt",
    "\xF8\x88\x80\x80\x80 five bytes.txt",
    "\x83\x5C shift-jis backslash.txt",
    "\x80\x80\x80 continuations only.txt",
    "\xFF*?[1] wildcards.txt",
    "\xFF\\\xFE backslash between.txt",
    "\xFF\nnew\xFEline.txt",
    "\xFF'\"$(id)`id`;|&.txt",
    "-\xFF leading dash.txt",
    ".\xFF hidden",
    "\x01\x1B[31m\x7F\xC2 control.txt",
    "truncated \xE2\x82"
  ].map { |name| name.b.freeze }.freeze

  def setup
    @dir = Dir.mktmpdir('ood_core ssh test')
    @adapter = ssh_adapter(bin_overrides: { 'ssh' => FAKE_SSH })
  end

  def teardown
    FileUtils.remove_entry(@dir)
    OodCore::Files::Adapters::Ssh.clear_dataroot_cache
  end

  def path(*parts)
    File.join(@dir, *parts)
  end

  def cluster
    OpenStruct.new(id: 'test', file_adapter: @adapter)
  end

  # Whether file permissions apply to this process. They don't for root, with capabilities such as
  # CAP_DAC_OVERRIDE, or on file systems that ignore them, as in some CI containers.
  def permissions_enforced?
    probe = path('permission probe')
    File.write(probe, '')
    File.chmod(0o000, probe)
    File.open(probe).close
    false
  rescue Errno::EACCES
    true
  ensure
    File.delete(probe) if File.exist?(probe)
  end

  # Whether dd on the cluster is from uutils coreutils, as on Ubuntu 26.04.
  def uutils_dd?
    stdout, = @adapter.call('dd', '--version')
    stdout.include?('uutils')
  end

  def test_dataroot
    ClimateControl.modify(HOME: path('home dir'), OOD_PORTAL: nil, APP_TOKEN: nil) do
      assert_equal(Pathname.new(path('home dir', 'ondemand', 'data', 'sys', 'dashboard')), @adapter.dataroot)
    end
  end

  def test_dataroot_timeout
    adapter = ssh_adapter(bin_overrides: { 'ssh' => FAKE_SSH }, dataroot_timeout: 1)

    start = Time.now
    error = ClimateControl.modify(FAKE_SSH_DELAY: '10') do
      assert_raises(OodCore::FilesAdapterError) { adapter.dataroot }
    end

    assert_operator(Time.now - start, :<, 5)
    assert_equal('Could not access cluster test: timed out after 1s (will retry in 300s)', error.message)
  end

  def test_write_and_read_back_awkward_file_names
    FILE_NAMES.each do |name|
      file = path(name)
      content = "content of #{name}"
      @adapter.write(file, content)

      assert_equal(content.b, File.binread(file), "write #{name.inspect}")
      assert_equal(content.b, @adapter.read(file).b, "read #{name.inspect}")
      assert_equal(content.bytesize, @adapter.size(file), "size #{name.inspect}")
      assert(@adapter.exist?(file), "exist? #{name.inspect}")
      refute(@adapter.directory?(file), "directory? #{name.inspect}")
      assert(@adapter.editable?(file), "editable? #{name.inspect}")
    end
  end

  def test_write_and_read_back_invalid_utf8_file_names
    skip('known limitation: uutils dd refuses paths that are not valid UTF-8') if uutils_dd?

    INVALID_UTF8_NAMES.each do |name|
      file = path(name)
      content = "content of #{name}".b
      @adapter.write(file, content)

      assert_equal(content, File.binread(file), "write #{name.inspect}")
      assert_equal(content, @adapter.read(file).b, "read #{name.inspect}")
      assert_equal(content.bytesize, @adapter.size(file), "size #{name.inspect}")
      assert(@adapter.exist?(file), "exist? #{name.inspect}")
      refute(@adapter.directory?(file), "directory? #{name.inspect}")
      assert(@adapter.editable?(file), "editable? #{name.inspect}")
    end
  end

  def test_ls_awkward_file_names
    FILE_NAMES.each { |name| File.write(path(name), name) }

    files = @adapter.ls(@dir)

    assert_equal(FILE_NAMES.sort, files.map { |f| f[:name] }.sort)
    files.each do |f|
      assert_equal(f[:name].bytesize, f[:size])
      assert(f[:name].valid_encoding?)
    end
  end

  def test_ls_invalid_utf8_file_names
    INVALID_UTF8_NAMES.each { |name| File.binwrite(path(name), name) }

    files = @adapter.ls(@dir)

    assert_equal(INVALID_UTF8_NAMES.sort, files.map { |f| f[:name].b }.sort)
    files.each { |f| assert_equal(f[:name].bytesize, f[:size], f[:name].inspect) }
  end

  def test_ls_recursive_invalid_utf8_file_names
    FileUtils.mkdir_p(path("dir \xFF".b, "sub \xFE".b))
    INVALID_UTF8_NAMES.each { |name| File.binwrite(path("dir \xFF".b, "sub \xFE".b, name), name) }

    expected = INVALID_UTF8_NAMES.map { |name| path("dir \xFF".b, "sub \xFE".b, name) }
    assert_equal(expected.sort, @adapter.ls_recursive(path("dir \xFF".b)).map(&:b).sort)
  end

  def test_ls_attributes
    Dir.mkdir(path('sub dir'))
    File.write(path('script.sh'), 'echo hi')
    File.chmod(0o750, path('script.sh'))
    File.symlink(path('script.sh'), path('link'))
    mtime = Time.at(1_760_000_000)
    File.utime(mtime, mtime, path('script.sh'))

    files = @adapter.ls(@dir).to_h { |f| [f[:name], f] }

    assert(files['sub dir'][:directory])
    assert_nil(files['sub dir'][:size])
    assert_equal(0o750, files['script.sh'][:mode])
    assert_equal(mtime.to_i, files['script.sh'][:date])
    assert_equal(Etc.getpwuid(Process.uid).name, files['script.sh'][:owner])
    # symlinks are followed
    assert_equal(files['script.sh'].except(:name), files['link'].except(:name))
  end

  def test_ls_skips_special_files
    File.write(path('file'), '')
    File.symlink(path('nowhere'), path('broken link'))
    system('mkfifo', path('fifo'))

    assert_equal(['file'], @adapter.ls(@dir).map { |f| f[:name] })
  end

  def test_ls_missing_or_unreadable_directory_raises
    assert_raises(StandardError) { @adapter.ls(path('missing')) }

    skip('file permissions do not apply') unless permissions_enforced?
    Dir.mkdir(path('unreadable'), 0o000)
    error = assert_raises(StandardError) { @adapter.ls(path('unreadable')) }
    assert_match(/Permission denied/, error.message)
  ensure
    File.chmod(0o700, path('unreadable')) if File.exist?(path('unreadable'))
  end

  def test_ls_recursive
    FileUtils.mkdir_p(path('a b', 'c'))
    File.write(path('a b', 'one'), '')
    File.write(path('a b', 'c', "new\nline"), '')

    assert_equal([path('a b', 'c', "new\nline"), path('a b', 'one')], @adapter.ls_recursive(path('a b')).sort)
  end

  # Like zip downloads of local directories: a symlink to the directory itself (e.g. ~/scratch) and symlinks to files
  # are followed, symlinks to directories inside it are not.
  def test_ls_recursive_follows_symlinks_like_local_downloads
    FileUtils.mkdir_p(path('target', 'sub'))
    File.write(path('target', 'sub', 'file'), '')
    File.symlink(path('target'), path('link'))
    File.symlink(path('target', 'sub', 'file'), path('target', 'file link'))
    File.symlink(path('target', 'sub'), path('target', 'dir link'))
    File.symlink(path('nowhere'), path('target', 'broken link'))

    assert_equal([path('link', 'file link'), path('link', 'sub', 'file')], @adapter.ls_recursive(path('link')).sort)
  end

  def test_call_with_timeout
    out, _, status = @adapter.call('echo', 'hi', timeout: 5)

    assert_equal(["hi\n", true], [out, status.success?])
  end

  def test_read_streams_large_files
    content = Random.new(1).bytes(200_000)
    File.binwrite(path('big file'), content)

    chunks = []
    @adapter.read(path('big file')) { |data| chunks << data }

    assert_operator(chunks.size, :>, 1)
    assert_equal(content, chunks.join.b)
  end

  def test_read_streams_despite_ssh_warnings
    File.write(path('file'), 'content')

    chunks = []
    ClimateControl.modify(FAKE_SSH_WARN: '1') do
      @adapter.read(path('file')) { |data| chunks << data }
    end

    assert_equal('content', chunks.join)
  end

  def test_read_streaming_missing_file_raises
    error = assert_raises(StandardError) { @adapter.read(path('missing')) { |_| nil } }
    assert_match(/\ACommand exited with status 1\ncat: .*No such file or directory\z/, error.message)
  end

  # A process left running by the command keeps its error output open after it exits.
  # sh starts the process, as subshell and redirection syntax differs between login shells (e.g. fish, tcsh).
  def test_streaming_command_leaving_a_process_running
    File.write(path('file'), 'content')

    _, err = capture_io do
      data = +''
      @adapter.send(:call_popen, 'cat', Shellwords.escape(path('file')), ';', 'sh', '-c', "'sleep 1 >&2 &'") do |o|
        data << o.read
      end
      assert_equal('content', data)
      # Give a reader thread that was cut off time to report it.
      sleep(0.2)
    end
    assert_empty(err)
  end

  def test_write_binary_and_empty_content
    content = Random.new(2).bytes(100_000)
    @adapter.write(path('binary'), content)
    @adapter.write(path('empty'), '')

    assert_equal(content, File.binread(path('binary')))
    assert_equal('', File.read(path('empty')))
  end

  # Rails sets Encoding.default_internal, which makes Ruby convert strings written to pipes.
  def test_write_binary_content_with_rails_encoding_defaults
    content = "\xFF\xFE binary".b
    default_internal = Encoding.default_internal
    Encoding.default_internal = Encoding::UTF_8

    @adapter.write(path('binary'), content)

    assert_equal(content, File.binread(path('binary')))
  ensure
    Encoding.default_internal = default_internal
  end

  def test_write_overwrites
    File.write(path('file'), 'a much longer original content')
    @adapter.write(path('file'), 'new')

    assert_equal('new', File.read(path('file')))
  end

  # A shell redirect would fail for existing files if the user's shell startup files set noclobber.
  def test_write_overwrites_with_noclobber
    File.write(path('bashrc'), "set -o noclobber\n")
    File.write(path('file'), 'old')

    # The fake ssh's bash -c reads BASH_ENV, like bash started by sshd reads ~/.bashrc.
    ClimateControl.modify(BASH_ENV: path('bashrc')) { @adapter.write(path('file'), 'new') }

    assert_equal('new', File.read(path('file')))
  end

  def test_touch_and_mkdir
    @adapter.mkdir(path('a b', '$c', 'd'))
    @adapter.touch(path('a b', '$c', 'd', 'new file'))

    assert(File.directory?(path('a b', '$c', 'd')))
    assert(@adapter.directory?(path('a b', '$c', 'd')))
    assert_equal('', File.read(path('a b', '$c', 'd', 'new file')))
  end

  def test_missing_paths
    refute(@adapter.exist?(path('missing')))
    assert_raises(StandardError) { @adapter.directory?(path('missing')) }
    assert_raises(StandardError) { @adapter.size(path('missing')) }
    assert_raises(StandardError) { @adapter.read(path('missing')) }
    assert_raises(StandardError) { @adapter.ls_recursive(path('missing')) }
    refute(@adapter.editable?(path('missing')))
  end

  def test_not_editable
    File.write(path('read only'), '')
    File.chmod(0o444, path('read only'))
    Dir.mkdir(path('dir'))

    refute(@adapter.editable?(path('read only'))) if permissions_enforced?
    refute(@adapter.editable?(path('dir')))
  end

  def test_readable?
    File.write(path("it's"), '')
    File.symlink(path("it's"), path('link'))
    File.write(path('secret'), '')
    File.chmod(0o000, path('secret'))

    assert(@adapter.readable?(path("it's")))
    assert(@adapter.readable?(path('link')))
    refute(@adapter.readable?(path('missing')))
    refute(@adapter.readable?(path('secret'))) if permissions_enforced?
  end

  def test_mv_cp_rm_within_cluster
    FileUtils.mkdir_p(path('src dir', 'sub'))
    File.write(path('src dir', 'sub', "it's"), 'x')

    @adapter.copy_with_progress(cluster, cluster, path('src dir'), path('copy dir'))
    assert_equal('x', File.read(path('copy dir', 'sub', "it's")))

    @adapter.move_with_progress(cluster, cluster, path('copy dir'), path('moved dir'))
    refute(File.exist?(path('copy dir')))
    assert_equal('x', File.read(path('moved dir', 'sub', "it's")))

    @adapter.remove_with_progress(path('moved dir'))
    refute(File.exist?(path('moved dir')))
    assert(File.exist?(path('src dir', 'sub', "it's")))
  end

  def test_mv_cp_rm_invalid_utf8_file_names
    INVALID_UTF8_NAMES.each do |name|
      File.binwrite(path(name), name)

      @adapter.copy_with_progress(cluster, cluster, path(name), path("copy #{name}".b))
      @adapter.move_with_progress(cluster, cluster, path("copy #{name}".b), path("moved #{name}".b))
      refute(File.exist?(path("copy #{name}".b)), "move #{name.inspect}")
      assert_equal(name, File.binread(path("moved #{name}".b)), "move #{name.inspect}")

      @adapter.remove_with_progress(path("moved #{name}".b))
      refute(File.exist?(path("moved #{name}".b)), "remove #{name.inspect}")
      assert(File.exist?(path(name)), "remove #{name.inspect}")
    end
  end

  def test_mv_does_not_move_into_an_existing_directory
    FileUtils.mkdir_p([path('src'), path('dst', 'other')])

    assert_raises(StandardError) { @adapter.send(:mv, path('src'), path('dst')) }
    assert(File.directory?(path('src')))
    refute(File.exist?(path('dst', 'src')))
  end

  # Runs the block with a cluster that has everything on the PATH except the given commands.
  def without_commands_on_cluster(*commands)
    bin = path('cluster bin')
    Dir.mkdir(bin)
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
      Dir.glob(File.join(dir, '*')).each do |file|
        name = File.basename(file)
        next if commands.include?(name) || File.exist?(File.join(bin, name))

        File.symlink(file, File.join(bin, name))
      end
    end
    ClimateControl.modify(FAKE_SSH_PATH: bin) { yield }
  end

  def test_commands_not_installed_on_cluster
    File.write(path('file.txt'), 'x')

    without_commands_on_cluster('file', 'rsync', 'cat') do
      error = assert_raises(StandardError) { @adapter.mime_type(path('file.txt')) }
      assert_equal("Could not check file type of #{path('file.txt')}: file is not installed on cluster test", error.message)

      error = assert_raises(StandardError) { @adapter.copy_with_progress('fs', cluster, path('file.txt'), path('up', 'file.txt')) }
      assert_equal('rsync is not installed on cluster test', error.message)

      error = assert_raises(StandardError) { @adapter.copy_with_progress(cluster, 'fs', path('file.txt'), path('down', 'file.txt')) }
      assert_equal('rsync is not installed on cluster test', error.message)

      error = assert_raises(StandardError) { @adapter.read(path('file.txt')) { |_| nil } }
      assert_equal('cat is not installed on cluster test', error.message)
    end
  end

  def test_mime_type
    File.write(path('text file.txt'), 'hello')
    File.write(path('empty'), '')

    assert_equal('text/plain', @adapter.mime_type(path('text file.txt')))
    assert_equal('inode/x-empty', @adapter.mime_type(path('empty')))
    assert_raises(StandardError) { @adapter.mime_type(path('missing')) }
  end

  def test_directory_size
    FileUtils.mkdir_p(path('dir', 'sub dir'))
    File.write(path('dir', 'sub dir', 'file'), 'x' * 10_000)
    File.symlink(path('nowhere'), path('dir', 'broken link'))

    assert_operator(@adapter.directory_size(path('dir'), timeout: 5), :>=, 10_000)
    assert_raises(OodCore::FilesAdapterError) { @adapter.directory_size(path('missing'), timeout: 5) }
  end

  # rsync transfers between the local file system and the cluster

  def assert_progress(progress)
    refute_empty(progress)
    assert_equal(100, progress.last)
    assert_equal(progress.sort, progress)
  end

  def test_copy_file_local_to_cluster
    File.write(path("local it's"), 'x' * 100_000)

    progress = []
    @adapter.copy_with_progress('fs', cluster, path("local it's"), path('remote dir', "it's")) { |p| progress << p }

    assert_equal('x' * 100_000, File.read(path('remote dir', "it's")))
    assert(File.exist?(path("local it's")))
    assert_progress(progress)
  end

  def test_move_directory_cluster_to_local
    FileUtils.mkdir_p(path('remote dir', 'sub $dir'))
    File.write(path('remote dir', 'sub $dir', 'file'), 'x')

    progress = []
    @adapter.move_with_progress(cluster, 'fs', path('remote dir'), path('new local', 'remote dir')) { |p| progress << p }

    assert_equal('x', File.read(path('new local', 'remote dir', 'sub $dir', 'file')))
    refute(File.exist?(path('remote dir')))
    assert_progress(progress)
  end

  def test_move_directory_local_to_cluster
    FileUtils.mkdir_p(path('local dir', 'empty dir'))
    FileUtils.mkdir_p(path('local dir', 'sub'))
    File.write(path('local dir', 'sub', 'file'), 'x')

    @adapter.move_with_progress('fs', cluster, path('local dir'), path('remote', 'local dir'))

    assert_equal('x', File.read(path('remote', 'local dir', 'sub', 'file')))
    assert(File.directory?(path('remote', 'local dir', 'empty dir')))
    refute(File.exist?(path('local dir')))
  end

  def test_remove_empty_directories_keeps_files
    FileUtils.mkdir_p(path('dir', 'empty', 'nested empty'))
    FileUtils.mkdir_p(path('dir', 'not empty'))
    File.write(path('dir', 'not empty', 'file'), 'x')

    @adapter.send(:remove_empty_directories, path('dir'), remote: true)

    refute(File.exist?(path('dir', 'empty')))
    assert_equal('x', File.read(path('dir', 'not empty', 'file')))
  end

  def test_rsync_remote_paths_are_not_interpreted_by_the_remote_shell
    name = %q(a;touch "$SSH_TEST_MARKER";b c)
    Dir.mkdir(path('remote'))
    File.write(path('remote', name), 'x')

    ClimateControl.modify(SSH_TEST_MARKER: path('injected')) do
      @adapter.copy_with_progress(cluster, 'fs', path('remote', name), path('local', name))
      @adapter.copy_with_progress('fs', cluster, path('local', name), path('remote', 'copy', name))
    end

    refute(File.exist?(path('injected')), 'file name was executed by the remote shell')
    assert_equal('x', File.read(path('local', name)))
    assert_equal('x', File.read(path('remote', 'copy', name)))
  end

  def write_files(dir, names)
    FileUtils.mkdir_p(dir)
    names.each { |name| File.write(File.join(dir, name), name) }
  end

  def test_transfer_awkward_file_names
    write_files(path('remote'), FILE_NAMES)

    FILE_NAMES.each do |name|
      @adapter.copy_with_progress(cluster, 'fs', path('remote', name), path('local', name))
      @adapter.copy_with_progress('fs', cluster, path('local', name), path('remote', 'copy', name))
    end

    FILE_NAMES.each do |name|
      assert_equal(name.b, File.binread(path('local', name)), "download #{name.inspect}")
      assert_equal(name.b, File.binread(path('remote', 'copy', name)), "upload #{name.inspect}")
    end
  end

  def test_transfer_invalid_utf8_file_names
    write_files(path('remote'), INVALID_UTF8_NAMES)

    INVALID_UTF8_NAMES.each do |name|
      @adapter.copy_with_progress(cluster, 'fs', path('remote', name), path('local', name))
      @adapter.copy_with_progress('fs', cluster, path('local', name), path('remote', 'copy', name))
    end

    INVALID_UTF8_NAMES.each do |name|
      assert_equal(name, File.binread(path('local', name)), "download #{name.inspect}")
      assert_equal(name, File.binread(path('remote', 'copy', name)), "upload #{name.inspect}")
    end
    assert_equal(INVALID_UTF8_NAMES.sort, Dir.children(path('local')).map(&:b).sort)
    assert_equal(INVALID_UTF8_NAMES.sort, Dir.children(path('remote', 'copy')).map(&:b).sort)
  end

  def test_transfer_directories_with_invalid_utf8_names
    dir = "d\xFF[1]\xC0\xAF".b
    write_files(path('remote', dir), INVALID_UTF8_NAMES)

    @adapter.copy_with_progress(cluster, 'fs', path('remote', dir), path('local', dir))
    @adapter.copy_with_progress('fs', cluster, path('local', dir), path('remote', "copy #{dir}".b))

    assert_equal(INVALID_UTF8_NAMES.sort, Dir.children(path('local', dir)).map(&:b).sort)
    assert_equal(INVALID_UTF8_NAMES.sort, Dir.children(path('remote', "copy #{dir}".b)).map(&:b).sort)
    INVALID_UTF8_NAMES.each do |name|
      assert_equal(name, File.binread(path('remote', "copy #{dir}".b, name)), name.inspect)
    end
  end

  # Names with wildcards and backslashes, and other files that they match as patterns, which must not be transferred
  # instead.
  WILDCARD_NAMES = { 'f[1].txt' => 'f1.txt', 'a*?.txt' => 'abc.txt', 'b\\[2].txt' => 'b[2].txt' }.freeze

  def test_download_wildcard_names
    write_files(path('remote'), WILDCARD_NAMES.keys + WILDCARD_NAMES.values)

    WILDCARD_NAMES.each_key do |name|
      @adapter.copy_with_progress(cluster, 'fs', path('remote', name), path('copied', name))
      @adapter.move_with_progress(cluster, 'fs', path('remote', name), path('moved', name))
    end

    assert_equal(WILDCARD_NAMES.keys.sort, Dir.children(path('copied')).sort)
    assert_equal(WILDCARD_NAMES.keys.sort, Dir.children(path('moved')).sort)
    WILDCARD_NAMES.each_key do |name|
      assert_equal(name, File.read(path('copied', name)), "copy #{name.inspect}")
      assert_equal(name, File.read(path('moved', name)), "move #{name.inspect}")
    end
    # Only the moved files are removed from the cluster.
    assert_equal(WILDCARD_NAMES.values.sort, Dir.children(path('remote')).sort)
  end

  def test_upload_wildcard_names
    write_files(path('local'), WILDCARD_NAMES.keys + ['upload'])
    write_files(path('remote'), WILDCARD_NAMES.values)
    write_files(path('remote', 'd1'), ['x'])

    WILDCARD_NAMES.each_key do |name|
      @adapter.copy_with_progress('fs', cluster, path('local', name), path('remote', name))
    end
    # Under another name, like uploads from Rack tempfiles, into a new directory that matches an existing one.
    @adapter.move_with_progress('fs', cluster, path('local', 'upload'), path('remote', 'd[1]', 'x'))

    (WILDCARD_NAMES.keys + WILDCARD_NAMES.values).each do |name|
      assert_equal(name, File.read(path('remote', name)), name.inspect)
    end
    assert_equal('upload', File.read(path('remote', 'd[1]', 'x')))
    assert_equal('x', File.read(path('remote', 'd1', 'x')))
    refute(File.exist?(path('local', 'upload')))
  end

  def test_transfer_wildcard_names_under_backslashes
    dir = path('remote', 'back\\slash', 'x\\y[1]')
    write_files(dir, ['f[1].txt', 'f1.txt'])
    # What x\y[1]/f[1].txt matches as a pattern
    FileUtils.mkdir_p(path('remote', 'back\\slash', 'xy1'))
    File.write(path('remote', 'back\\slash', 'xy1', 'f1.txt'), 'other')

    @adapter.copy_with_progress(cluster, 'fs', File.join(dir, 'f[1].txt'), path('local', 'f[1].txt'))
    @adapter.copy_with_progress('fs', cluster, path('local', 'f[1].txt'), File.join(dir, 'copy[1].txt'))

    assert_equal('f[1].txt', File.read(path('local', 'f[1].txt')))
    assert_equal('f[1].txt', File.read(File.join(dir, 'copy[1].txt')))
    assert_equal(['f1.txt'], Dir.children(path('remote', 'back\\slash', 'xy1')))
  end

  def test_transfer_directories_with_wildcard_names
    write_files(path('remote', 'd[1]'), ['in d[1]'])
    write_files(path('remote', 'd1'), ['in d1'])
    write_files(path('remote', 'e1'), ['in e1'])
    write_files(path('local', 'd[1]'), ['uploaded'])

    @adapter.copy_with_progress(cluster, 'fs', path('remote', 'd[1]'), path('downloaded', 'd[1]'))
    @adapter.copy_with_progress('fs', cluster, path('local', 'd[1]'), path('remote', 'd[1]'))
    @adapter.copy_with_progress('fs', cluster, path('local', 'd[1]'), path('remote', 'e[1]'))

    assert_equal(['in d[1]'], Dir.children(path('downloaded', 'd[1]')))
    assert_equal(['in d[1]', 'uploaded'], Dir.children(path('remote', 'd[1]')).sort)
    assert_equal(['uploaded'], Dir.children(path('remote', 'e[1]')))
    assert_equal(['in d1'], Dir.children(path('remote', 'd1')))
    assert_equal(['in e1'], Dir.children(path('remote', 'e1')))
  end

  # The adapter sets these for rsync, whatever the user's environment has.
  def test_rsync_ignores_argument_settings_from_the_environment
    write_files(path('remote'), ['f[1].txt', 'f1.txt'])

    ClimateControl.modify(RSYNC_PROTECT_ARGS: '1', RSYNC_OLD_ARGS: '0') do
      @adapter.copy_with_progress(cluster, 'fs', path('remote', 'f[1].txt'), path('local', 'f[1].txt'))
      @adapter.copy_with_progress('fs', cluster, path('local', 'f[1].txt'), path('remote', 'copy', 'f[1].txt'))
    end

    assert_equal('f[1].txt', File.read(path('local', 'f[1].txt')))
    assert_equal('f[1].txt', File.read(path('remote', 'copy', 'f[1].txt')))
  end

  def test_upload_into_existing_directories
    write_files(path('remote', 'dir'), ['existing'])
    write_files(path('local'), ['file'])
    write_files(path('local', 'sub'), ['in sub'])

    @adapter.copy_with_progress('fs', cluster, path('local', 'file'), path('remote', 'dir', 'file'))
    @adapter.copy_with_progress('fs', cluster, path('local', 'sub'), path('remote', 'dir', 'sub'))
    # Like rsync, a file uploaded onto an existing directory goes into it.
    @adapter.copy_with_progress('fs', cluster, path('local', 'file'), path('remote', 'dir'))

    assert_equal(['existing', 'file', 'sub'], Dir.children(path('remote', 'dir')).sort)
    assert_equal('file', File.read(path('remote', 'dir', 'file')))
    assert_equal(['in sub'], Dir.children(path('remote', 'dir', 'sub')))
    assert_equal('existing', File.read(path('remote', 'dir', 'existing')))
  end

  def mode(*parts)
    File.stat(path(*parts)).mode & 0o7777
  end

  # Uploads are Rack tempfiles that only the user can read, which are written to the cluster as new content.
  def test_write_io_sets_permissions_as_for_new_files
    Dir.mkdir(path('remote'))
    File.chmod(0o2775, path('remote'))
    File.write(path('remote', 'existing'), 'a much longer original content')
    File.chmod(0o640, path('remote', 'existing'))
    upload = Tempfile.new('upload')
    upload.write('new')
    upload.flush

    File.open(upload.path, 'rb') { |io| @adapter.write(path('remote', 'new'), io) }
    File.open(upload.path, 'rb') { |io| @adapter.write(path('remote', 'existing'), io) }

    assert_equal('new', File.read(path('remote', 'new')))
    assert_equal(0o666 & ~File.umask, mode('remote', 'new'))
    assert_equal(File.stat(path('remote')).gid, File.stat(path('remote', 'new')).gid)
    assert_equal('new', File.read(path('remote', 'existing')))
    assert_equal(0o640, mode('remote', 'existing'))
  ensure
    upload&.close!
  end

  def test_copy_keeps_permissions
    Dir.mkdir(path('remote'))
    upload = Tempfile.new('upload')

    @adapter.copy_with_progress('fs', cluster, upload.path, path('remote', 'copy'))

    assert_equal(0o600, mode('remote', 'copy'))
  ensure
    upload&.close!
  end

  # Larger than a chunk, with bytes that are not valid UTF-8, and Rails' encoding defaults.
  def test_write_io_streams_binary_content_with_progress
    content = Random.new(3).bytes((2.5 * OodCore::Files::Adapters::Ssh::WRITE_CHUNK_SIZE).to_i)
    default_internal = Encoding.default_internal
    Encoding.default_internal = Encoding::UTF_8

    progress = []
    @adapter.write(path('binary'), StringIO.new(content)) { |percent| progress << percent }

    assert_equal(content, File.binread(path('binary')))
    assert_equal([40, 80, 100], progress)
  ensure
    Encoding.default_internal = default_internal
  end

  def test_write_io_empty
    @adapter.write(path('empty'), StringIO.new(''))

    assert_equal('', File.read(path('empty')))
  end

  def test_write_creates_missing_parent_directories
    @adapter.write(path('new dir', '$x', 'string'), 'string')
    @adapter.write(path('new dir', '$x', 'sub', 'io'), StringIO.new('io'))

    assert_equal('string', File.read(path('new dir', '$x', 'string')))
    assert_equal('io', File.read(path('new dir', '$x', 'sub', 'io')))
  end

  def test_write_into_a_file_raises
    File.write(path('file'), 'not a directory')

    [-> { 'x' }, -> { StringIO.new('x' * (4 * OodCore::Files::Adapters::Ssh::WRITE_CHUNK_SIZE)) }].each do |content|
      error = assert_raises(StandardError) { @adapter.write(path('file', 'sub', 'new'), content.call) }
      assert_match(/\ACould not write #{Regexp.escape(path('file', 'sub', 'new'))}: mkdir: /, error.message)
    end
  end

  # Fails in dd after creating the parent directories, while the IO is still being written.
  def test_write_io_failure_raises
    skip('file permissions do not apply') unless permissions_enforced?
    Dir.mkdir(path('read-only'))
    File.chmod(0o555, path('read-only'))
    content = StringIO.new('x' * (4 * OodCore::Files::Adapters::Ssh::WRITE_CHUNK_SIZE))

    error = assert_raises(StandardError) { @adapter.write(path('read-only', 'file'), content) }
    assert_match(%r{\ACould not write #{Regexp.escape(path('read-only', 'file'))}: dd: .*Permission denied\z},
                 error.message)
  ensure
    File.chmod(0o755, path('read-only')) if File.exist?(path('read-only'))
  end

  def test_rsync_failure_raises

    error = assert_raises(StandardError) { @adapter.copy_with_progress('fs', cluster, path('missing'), path('dst')) }
    assert_match(/\Arsync exited with status \d+\n.*No such file or directory/m, error.message)
  end
end
