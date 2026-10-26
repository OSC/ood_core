require_relative 'ssh_test_helper'
require 'tmpdir'

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
    assert_raises(StandardError) { @adapter.write(path('missing', 'file'), 'x') }
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

    without_commands_on_cluster('file', 'cat') do
      error = assert_raises(StandardError) { @adapter.mime_type(path('file.txt')) }
      assert_equal("Could not check file type of #{path('file.txt')}: file is not installed on cluster test", error.message)

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
end
