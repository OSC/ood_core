require_relative 'ssh_test_helper'

# Unit tests for the ssh files adapter. Commands are stubbed, nothing is executed.
class SshTest < Minitest::Test
  include TestHelper
  include SshTestHelper

  def adapter
    @adapter ||= ssh_adapter
  end

  def teardown
    OodCore::Files::Adapters::Ssh.clear_dataroot_cache
  end

  def ok(stdout = '')
    [stdout, '', exit_status(0)]
  end

  def failed(code, stderr = 'boom', stdout: '')
    [stdout, stderr, exit_status(code)]
  end

  # Factory

  def test_factory_builds_ssh_adapter
    a = OodCore::Files::Factory.build({ adapter: 'ssh', host: 'login.example', cluster_id: 'owens',
                                        bin_overrides: { 'ssh' => '/opt/ssh' } })

    assert_instance_of(OodCore::Files::Adapters::Ssh, a)
    assert_equal('login.example', a.host)
    assert_equal('owens', a.cluster_id)
    assert_equal({ 'ssh' => '/opt/ssh' }, a.bin_overrides)
  end

  def test_factory_accepts_string_keys
    a = OodCore::Files::Factory.build({ 'adapter' => 'ssh', 'host' => 'login.example', 'cluster_id' => 'owens' })

    assert_equal('login.example', a.host)
    assert_equal({}, a.bin_overrides)
  end

  def test_factory_dataroot_options
    a = OodCore::Files::Factory.build({ adapter: 'ssh', host: 'login.example', cluster_id: 'owens' })
    assert_equal([20, 300], [a.dataroot_timeout, a.dataroot_retry_after])
    assert_kind_of(Integer, a.dataroot_timeout)

    a = OodCore::Files::Factory.build({ adapter: 'ssh', host: 'login.example', cluster_id: 'owens',
                                        dataroot_timeout: 5, dataroot_retry_after: '60' })
    assert_equal([5, 60], [a.dataroot_timeout, a.dataroot_retry_after])
  end

  def test_factory_strict_host_checking
    config = { adapter: 'ssh', host: 'login.example', cluster_id: 'owens' }

    assert(OodCore::Files::Factory.build(config).strict_host_checking)
    refute(OodCore::Files::Factory.build(config.merge(strict_host_checking: false)).strict_host_checking)
  end

  def test_factory_ssh_port
    config = { adapter: 'ssh', host: 'login.example', cluster_id: 'owens' }

    assert_nil(OodCore::Files::Factory.build(config).ssh_port)
    assert_equal(2222, OodCore::Files::Factory.build(config.merge(ssh_port: 2222)).ssh_port)
  end

  def test_factory_unknown_adapter
    error = assert_raises(LoadError) { OodCore::Files::Factory.build({ adapter: 'nope', cluster_id: 'owens' }) }
    assert_equal("Could not load 'nope'. Make sure that the files adapter in the configuration file is valid.",
                 error.message)
  end

  def test_factory_requires_host
    [{}, { host: nil }, { host: '' }].each do |host|
      error = assert_raises(ArgumentError, host.inspect) do
        OodCore::Files::Factory.build({ adapter: 'ssh', cluster_id: 'owens' }.merge(host))
      end
      assert_equal('No host specified for the files adapter of cluster owens', error.message)
    end
  end

  # Command construction

  def test_ssh_command_uses_bin_overrides
    ssh, args = ssh_adapter(bin_overrides: { 'ssh' => '/opt/bin/ssh' }).send(:ssh_command)

    assert_equal('/opt/bin/ssh', ssh)
    assert_includes(args.each_slice(2).to_a, ['-o', 'BatchMode=yes'])
  end

  def test_ssh_command_matches_job_adapter_ssh_options
    [true, false].each do |strict|
      _, args = OodCore::Files::Adapters::Ssh.new(host: 'fakehost', strict_host_checking: strict).send(:ssh_command)
      _, job_args = OodCore::Job::Adapters::Helper.ssh_wrap('fakehost', 'cmd', [], strict)

      assert_equal(job_args.take_while { |arg| arg != 'fakehost' }, args, "strict_host_checking: #{strict}")
    end

    _, args = ssh_adapter(ssh_port: 2222).send(:ssh_command)
    _, job_args = OodCore::Job::Adapters::Helper.ssh_wrap('fakehost', 'cmd', [], ssh_port: 2222)
    assert_equal(job_args.take_while { |arg| arg != 'fakehost' }, args, 'ssh_port: 2222')
  end

  def with_ood_ssh_port(port)
    old = ENV['OOD_SSH_PORT']
    ENV['OOD_SSH_PORT'] = port
    yield
  ensure
    ENV['OOD_SSH_PORT'] = old
  end

  def test_ssh_command_leaves_out_port_by_default
    with_ood_ssh_port(nil) do
      _, args = adapter.send(:ssh_command)

      refute_includes(args, '-p')
      assert_equal(['-o', 'BatchMode=yes'], args.first(2))
    end
  end

  def test_ssh_command_uses_ssh_port
    with_ood_ssh_port('2200') do
      _, args = ssh_adapter(ssh_port: 2222).send(:ssh_command)

      assert_equal(['-p', '2222', '-o', 'BatchMode=yes'], args.first(4))
    end
  end

  def test_ssh_command_falls_back_to_ood_ssh_port
    with_ood_ssh_port('2200') do
      _, args = adapter.send(:ssh_command)

      assert_equal(['-p', '2200', '-o', 'BatchMode=yes'], args.first(4))
    end
  end

  def test_ssh_command_strict_host_checking_by_default
    _, args = adapter.send(:ssh_command)

    assert_includes(args.each_slice(2).to_a, ['-o', 'StrictHostKeyChecking=yes'])
  end

  def test_ssh_wrap_passes_args_verbatim_after_host
    cmd, args = adapter.send(:ssh_wrap, 'cat', ['>/tmp/a\\ b'])
    _, ssh_args = adapter.send(:ssh_command)

    assert_equal(adapter.send(:ssh_command).first, cmd)
    assert_equal(ssh_args + ['fakehost', 'cat', '>/tmp/a\\ b'], args)
  end

  # Parsing helpers

  def test_unescape
    {
      'plain'               => 'plain',
      'with space'          => 'with space',
      'it\\\'s \\"odd\\"'   => %q(it's "odd"),
      'back\\\\slash'       => 'back\\slash',
      'new\\nline\\ttab'    => "new\nline\ttab",
      '\\a\\b\\v\\f\\r\\e'  => "\a\b\v\f\r\e",
      '\\033[31m'           => "\e[31m",
      'caf\\303\\251'       => 'café',
      'café'                => 'café'
    }.each do |escaped, expected|
      assert_equal(expected, adapter.send(:unescape, escaped).force_encoding('utf-8'), "unescape(#{escaped.inspect})")
    end
  end

  def test_unescape_keeps_invalid_utf8_bytes
    {
      '\\377'                         => "\xFF",
      '\\377\\376'                    => "\xFF\xFE",
      'caf\\351'                      => "caf\xE9",
      '\\303('                        => "\xC3(",
      '\\300\\257'                    => "\xC0\xAF",
      '\\300\\200'                    => "\xC0\x80",
      '\\355\\240\\200'               => "\xED\xA0\x80",
      '\\364\\220\\200\\200'          => "\xF4\x90\x80\x80",
      '\\200\\200'                    => "\x80\x80",
      'truncated \\342\\202'          => "truncated \xE2\x82",
      '\\203\\\\'                     => "\x83\\",
      '\\377\\\\\\376'                => "\xFF\\\xFE",
      '\\377\\n\\376'                 => "\xFF\n\xFE",
      "\\377 raw \xC3\xA9 \xFF".b     => "\xFF raw \xC3\xA9 \xFF"
    }.each do |escaped, expected|
      assert_equal(expected.b, adapter.send(:unescape, escaped), "unescape(#{escaped.inspect})")
    end
  end

  # Octal escapes are exactly three digits, and an escaped backslash does not start one.
  def test_unescape_octal_boundaries
    {
      '\\3771'     => "\xFF1",
      '\\0011'     => "\x011",
      '\\\\377'    => '\\377',
      '\\\\\\377'  => "\\\xFF",
      '\\\\n'      => '\\n',
      '\\\\\\\\'   => '\\\\'
    }.each do |escaped, expected|
      assert_equal(expected.b, adapter.send(:unescape, escaped), "unescape(#{escaped.inspect})")
    end
  end

  def test_parse_perms
    assert_equal(0o755, adapter.send(:parse_perms, 'rwxr-xr-x'))
    assert_equal(0o640, adapter.send(:parse_perms, 'rw-r-----'))
    assert_equal(0o777, adapter.send(:parse_perms, 'rwsrwsrwt'))
    assert_equal(0o640, adapter.send(:parse_perms, 'rwSr-----'))
    assert_equal(0, adapter.send(:parse_perms, 'rwx'))
  end

  # stat, size, exist?, directory?

  def test_stat
    adapter.expects(:call).with('stat', '--dereference', '--format', '%f', '/a\\ b').returns(ok("41ed\n"))

    assert_equal(0o40755, adapter.send(:stat, '/a b'))
  end

  # stat exits with 1 for missing paths, but also e.g. when permission is denied.
  def test_stat_failure_reports_stderr
    adapter.stubs(:call).returns(failed(1, "stat: cannot statx '/a/b': Permission denied"))

    error = assert_raises(StandardError) { adapter.send(:stat, '/a/b') }
    assert_equal("Could not stat /a/b: stat: cannot statx '/a/b': Permission denied", error.message)
  end

  def test_stat_other_error
    adapter.stubs(:call).returns(failed(255, 'ssh: connect to host fakehost: Connection refused'))

    error = assert_raises(StandardError) { adapter.send(:stat, '/a') }
    assert_match(/Could not stat \/a: ssh: connect/, error.message)
  end

  def test_directory?
    adapter.stubs(:call).returns(ok("41ed\n"))
    assert(adapter.directory?('/a'))

    adapter.stubs(:call).returns(ok("81a4\n"))
    refute(adapter.directory?('/a'))
  end

  def test_exist?
    adapter.stubs(:call).returns(ok("81a4\n"))
    assert(adapter.exist?('/a'))

    adapter.stubs(:call).returns(failed(1))
    refute(adapter.exist?('/a'))
  end

  def test_size
    adapter.expects(:call).with('stat', '--dereference', '--format', '%s', '/a').returns(ok("1234\n"))

    assert_equal(1234, adapter.size('/a'))
  end

  def test_size_failure_reports_stderr
    adapter.stubs(:call).returns(failed(1, "stat: cannot statx '/a/b': Permission denied"))

    error = assert_raises(StandardError) { adapter.size('/a/b') }
    assert_equal("Could not stat /a/b: stat: cannot statx '/a/b': Permission denied", error.message)
  end

  # ls

  LS_OUTPUT = <<~'LS'
    total 16
    drwxr-xr-x  2 bob users 4096 2026-10-01T12:00:00+0300 "sub dir"
    -rw-r-----. 1 bob users    6 2026-10-02T13:30:00+0000 "it's \"odd\".txt"
    -rwxr-xr-x+ 1 bob users    3 2026-10-02T13:30:00+0000 "new\nline"
    -rw-r--r--  1 bob users    5 2026-10-02T13:30:00+0000 "caf\303\251"
    -rw-r--r--  1 bob users    6 2026-10-02T13:30:00+0000 "\377\303(\300\257\\"
    srwxr-xr-x  1 bob users    0 2026-10-02T13:30:00+0000 "socket"
    prw-r--r--  1 bob users    0 2026-10-02T13:30:00+0000 "fifo"
    l?????????  ? ?   ?        ?                        ? "broken link"
  LS

  def test_ls
    adapter.expects(:call).with('ls', '-l', '--almost-all', '--quoting-style=c', '--time-style=+%Y-%m-%dT%H:%M:%S%z',
                                '--dereference', '--block-size=1', '/home/bob/my\\ dir').returns(ok(LS_OUTPUT))

    files = adapter.ls('/home/bob/my dir')

    assert_equal(['sub dir', %q(it's "odd".txt), "new\nline", 'café', "\xFF\xC3(\xC0\xAF\\"],
                 files.map { |f| f[:name] })

    dir, odd, newline, *, invalid = files
    assert_equal({
                   name:      'sub dir',
                   size:      nil,
                   directory: true,
                   date:      Time.utc(2026, 10, 1, 9).to_i,
                   owner:     'bob',
                   mode:      0o755
                 }, dir)
    assert_equal(6, odd[:size])
    assert_equal(0o640, odd[:mode])
    refute(odd[:directory])
    assert_equal(0o755, newline[:mode])
    files[..-2].each { |f| assert(f[:name].valid_encoding?, "#{f[:name].inspect} should be valid UTF-8") }
    # Names that are not valid UTF-8 keep their bytes, so they can be passed back to the adapter as paths.
    assert_equal(Encoding::UTF_8, invalid[:name].encoding)
    assert_equal(invalid[:size], invalid[:name].bytesize)
  end

  def test_ls_returns_partial_listing_on_failure
    adapter.stubs(:call).returns(failed(1, "ls: cannot access 'x': Permission denied", stdout: LS_OUTPUT))

    assert_equal(5, adapter.ls('/a').size)
  end

  def test_ls_failure_raises
    [[2, "ls: cannot open directory '/a': Permission denied"], [255, 'ssh: Connection refused']].each do |code, err|
      adapter.stubs(:call).returns(failed(code, "#{err}\n"))

      error = assert_raises(StandardError, "exit status #{code} should raise") { adapter.ls('/a') }
      assert_equal("Could not list /a: #{err}", error.message)
    end
  end

  # uutils coreutils 0.8.0 (Ubuntu 26.04) prints no space after the . or + that follows the permissions.
  def test_ls_without_space_after_permissions
    adapter.stubs(:call).returns(ok("total 4\n-rw-r--r--+1 bob users 3 2026-10-02T13:30:00+0000 \"f\"\n"))

    assert_equal([['f', 3, 0o644]], adapter.ls('/a').map { |f| f.values_at(:name, :size, :mode) })
  end

  def ls_fixture_entry(name, size:, mode:, directory: false, date: Time.utc(2026, 1, 2, 3, 4, 5))
    { name: name, size: size, directory: directory, date: date.to_i, owner: 'alice', mode: mode }
  end

  # The listing in the fixtures, without the broken symlink and the named pipe.
  def ls_fixture_listing
    [
      ls_fixture_entry('file', size: 1234, mode: 0o751),
      ls_fixture_entry('link', size: 1234, mode: 0o751),
      ls_fixture_entry('empty', size: 0, mode: 0o644),
      ls_fixture_entry('big', size: 5_000_000_000, mode: 0o644, date: Time.utc(2001, 1, 1)),
      ls_fixture_entry('dir', size: nil, mode: 0o755, directory: true),
      ls_fixture_entry('dirlink', size: nil, mode: 0o755, directory: true),
      ls_fixture_entry('setgid', size: nil, mode: 0o755, directory: true),
      ls_fixture_entry('sticky', size: nil, mode: 0o777, directory: true),
      *['with space', 'quote"d', 'back\\slash', "new\nline", "tab\tbed", 'ä😀', "invalid-\xFF", '-dash', '.hidden',
        'a" 1 b'].map { |name| ls_fixture_entry(name, size: 3, mode: 0o644) }
    ].sort_by { |f| f[:name].b }
  end

  # The fixtures are the output of the ls command run by #ls, listing the same directory with different
  # implementations of ls and in different locales. They were captured with TZ=Europe/Helsinki, and the user and group
  # renamed to alice and hpc.
  {
    'gnu_coreutils_9.7' => 'GNU coreutils 9.7',
    'uutils_0.8.0'      => 'uutils coreutils 0.8.0 (Ubuntu 26.04)',
    'uutils_0.10.0'     => 'uutils coreutils 0.10.0 (Ubuntu 26.04 updates)'
  }.each do |fixture, implementation|
    { 'utf8' => 'UTF-8', 'c' => 'C' }.each do |suffix, locale|
      define_method("test_ls_output_of_#{fixture.tr('.', '_')}_in_#{suffix}_locale") do
        # Command output is UTF-8 in Rails, which sets the default external encoding to UTF-8.
        stdout = File.read(File.expand_path("../../fixtures/ls/#{fixture}_#{suffix}.txt", __dir__), encoding: 'UTF-8')
        # ls exits with 1, as it can not follow the broken symlink.
        adapter.stubs(:call).returns(failed(1, "ls: cannot access 'listing/broken': No such file or directory",
                                            stdout: stdout))

        files = adapter.ls('/home/alice/listing').sort_by { |f| f[:name].b }

        assert_equal(ls_fixture_listing, files, "#{implementation} in the #{locale} locale")
      end
    end
  end

  def test_ls_recursive
    adapter.expects(:call).with('find', '-H', '/a\\ b', '-xtype', 'f', '-print0')
           .returns(ok("/a b/one\u0000/a b/sub/new\nline\u0000"))

    assert_equal(['/a b/one', "/a b/sub/new\nline"], adapter.ls_recursive('/a b'))
  end

  def test_ls_recursive_keeps_names_that_are_not_utf8
    adapter.stubs(:call).returns(ok("/a/ok\0/a/bad\xFF\0"))

    files = adapter.ls_recursive('/a')

    assert_equal(['/a/ok', "/a/bad\xFF"], files)
    assert_equal([Encoding::UTF_8], files.map(&:encoding).uniq)
  end

  def test_ls_recursive_failure
    [1, 255].each do |code|
      adapter.stubs(:call).returns(failed(code))

      assert_raises(StandardError, "exit status #{code} should raise") { adapter.ls_recursive('/a') }
    end
  end

  # editable?, read

  def test_editable?
    adapter.expects(:call).with('test', '-f', '/a\\ b', '-a', '-r', '/a\\ b', '-a', '-w', '/a\\ b').returns(ok)
    assert(adapter.editable?('/a b'))

    adapter.stubs(:call).returns(failed(1, ''))
    refute(adapter.editable?('/a b'))
  end

  def test_readable?
    adapter.expects(:call).with('test', '-r', '/a\\ b').returns(ok)
    assert(adapter.readable?('/a b'))

    adapter.stubs(:call).returns(failed(1, ''))
    refute(adapter.readable?('/a b'))
  end

  # e.g. a dropped connection must not look like missing permissions
  def test_readable_raises_if_it_can_not_check
    adapter.stubs(:call).returns(failed(255, 'ssh: connect to host fakehost: Connection refused'))

    error = assert_raises(StandardError) { adapter.readable?('/a') }
    assert_equal('Could not check /a: ssh: connect to host fakehost: Connection refused', error.message)
  end

  def test_read
    adapter.expects(:call).with('cat', '/a\\ b').returns(ok('content'))

    assert_equal('content', adapter.read('/a b'))
  end

  def test_read_failure
    adapter.stubs(:call).returns(failed(1, 'cat: /a: Permission denied'))

    error = assert_raises(StandardError) { adapter.read('/a') }
    assert_equal('Could not read file /a: cat: /a: Permission denied', error.message)
  end

  # Error output can name files that are not valid UTF-8.
  def test_read_failure_with_invalid_utf8_in_error_output
    adapter.stubs(:call).returns(failed(1, "cat: '/caf\xE9 x': No such file or directory\n"))

    error = assert_raises(StandardError) { adapter.read('/a') }
    assert_equal("Could not read file /a: cat: '/caf� x': No such file or directory", error.message)
  end

  # mime_type

  def test_mime_type
    adapter.expects(:call).with('file', '--dereference', '-Eb', '--mime-type', '/a\\ b').returns(ok("image/png\n"))

    assert_equal('image/png', adapter.mime_type('/a b'))
  end

  def test_commands_not_installed
    {
      'file' => -> { adapter.mime_type('/a') },
      'stat' => -> { adapter.size('/a') },
      'ls'   => -> { adapter.ls('/a') },
      'find' => -> { adapter.ls_recursive('/a') },
      'cat'  => -> { adapter.read('/a') },
      'du'   => -> { adapter.directory_size('/a', timeout: 5) }
    }.each do |cmd, operation|
      adapter.stubs(:call).returns(failed(127, "bash: line 1: #{cmd}: command not found"))

      error = assert_raises(StandardError, cmd) { operation.call }
      assert_match(/#{cmd} is not installed on cluster test\z/, error.message)
    end
  end

  def test_mime_type_failure
    adapter.stubs(:call).returns(failed(1, '', stdout: "/a: cannot open `/a' (No such file or directory)"))

    error = assert_raises(StandardError) { adapter.mime_type('/a') }
    assert_match(/No such file or directory/, error.message)
  end

  # directory_size

  def test_directory_size
    adapter.expects(:call).with('timeout', '5s', 'du', '-bLs', '/a\\ b').returns(ok("500\t/a b\n"))

    assert_equal(500, adapter.directory_size(Pathname.new('/a b'), timeout: 5))
  end

  def test_directory_size_with_broken_symlinks
    adapter.stubs(:call).returns(failed(1, "du: cannot access '/a b/link'", stdout: "500\t/a b\n"))

    assert_equal(500, adapter.directory_size('/a b', timeout: 5))
  end

  def test_directory_size_timeout
    adapter.stubs(:call).returns(failed(124, ''))

    assert_raises(Timeout::Error) { adapter.directory_size('/a b', timeout: 5) }
  end

  def test_directory_size_failure
    [
      [failed(1, "du: cannot access '/a b': No such file or directory\n"), "du: cannot access '/a b': No such file or directory"],
      [failed(1, 'du: oops', stdout: "garbage\t/a b\n"), 'du: oops'],
      [failed(255, 'ssh: Connection refused'), 'ssh: Connection refused']
    ].each do |result, err|
      adapter.stubs(:call).returns(result)

      error = assert_raises(OodCore::FilesAdapterError) { adapter.directory_size('/a b', timeout: 5) }
      assert_equal("du exited with status #{result.last.exitstatus}: #{err}", error.message)
    end
  end

  # dataroot

  def ssh_class
    OodCore::Files::Adapters::Ssh
  end

  def test_dataroot
    adapter.expects(:call).with('echo', '$HOME', timeout: 20).returns(ok("/home/me\n"))

    ClimateControl.modify(OOD_PORTAL: nil, APP_TOKEN: nil) do
      assert_equal(Pathname.new('/home/me/ondemand/data/sys/dashboard'), adapter.dataroot)
    end
  end

  def test_dataroot_uses_portal_and_app_token
    adapter.stubs(:call).returns(ok("/home/me\n"))

    ClimateControl.modify(OOD_PORTAL: 'ood', APP_TOKEN: 'dev/dashboard') do
      assert_equal(Pathname.new('/home/me/ood/data/dev/dashboard'), adapter.dataroot)
    end
  end

  # New adapters are created for every use, so the lookups have to be shared between them.
  def test_home_directory_is_looked_up_once_per_cluster
    ssh_class.any_instance.expects(:call).twice.returns(ok("/home/me\n"), ok("/home/other\n"))

    assert_equal(Pathname.new('/home/me'), ssh_adapter.home_directory)
    assert_equal(Pathname.new('/home/me'), ssh_adapter.home_directory)
    assert_equal(Pathname.new('/home/other'), ssh_adapter(cluster_id: 'other').home_directory)
    assert_equal(Pathname.new('/home/me'), ssh_adapter.home_directory)
  end

  def test_home_directory_validates_output
    ['', "\n", "relative/home\n", "Welcome to the cluster!\n/home/me\n", "/home/me\n/home/other\n",
     "/home/\xFF\n".b].each do |output|
      ssh_class.clear_dataroot_cache
      adapter.stubs(:call).returns(ok(output))

      error = assert_raises(OodCore::FilesAdapterError, output.inspect) { adapter.home_directory }
      assert_match(/\ACould not access cluster test: unexpected output when looking up the home directory: ".*" \(will retry in 300s\)\z/,
                   error.message)
    end
  end

  def test_home_directory_failure_reasons
    [
      [failed(255, "Warning: Permanently added 'fakehost'\nssh: connect to host fakehost port 22: Connection refused\n"),
       'ssh: connect to host fakehost port 22: Connection refused'],
      [failed(255, ''), 'ssh exited with status 255']
    ].each do |result, reason|
      ssh_class.clear_dataroot_cache
      adapter.stubs(:call).returns(result)

      error = assert_raises(OodCore::FilesAdapterError) { adapter.home_directory }
      assert_equal("Could not access cluster test: #{reason} (will retry in 300s)", error.message)
    end
  end

  def test_home_directory_when_ssh_cannot_be_run
    adapter.stubs(:call).raises(Errno::ENOENT, 'ssh')

    error = assert_raises(OodCore::FilesAdapterError) { adapter.home_directory }
    assert_equal('Could not access cluster test: No such file or directory - ssh (will retry in 300s)',
                 error.message)
  end

  # call raises Timeout::Error when the command does not finish within the dataroot_timeout.
  def test_home_directory_timeout
    adapter.stubs(:call).raises(Timeout::Error, 'timed out after 20s')

    error = assert_raises(OodCore::FilesAdapterError) { adapter.home_directory }
    assert_equal('Could not access cluster test: timed out after 20s (will retry in 300s)', error.message)
  end

  def test_failed_lookups_are_retried_after_dataroot_retry_after
    ssh_class.any_instance.stubs(:monotonic_now).returns(1000.0)
    ssh_class.any_instance.expects(:call).once.returns(failed(255, 'ssh: Connection refused'))
    assert_raises(OodCore::FilesAdapterError) { ssh_adapter(dataroot_retry_after: 60).dataroot }

    # No new lookups until the retry time, even from new adapters
    ssh_class.any_instance.stubs(:monotonic_now).returns(1059.0)
    error = assert_raises(OodCore::FilesAdapterError) { ssh_adapter(dataroot_retry_after: 60).dataroot }
    assert_equal('Could not access cluster test: ssh: Connection refused (will retry in 1s)', error.message)

    ssh_class.any_instance.stubs(:monotonic_now).returns(1060.0)
    ssh_class.any_instance.expects(:call).once.returns(ok("/home/me\n"))
    assert_equal(Pathname.new('/home/me'), ssh_adapter(dataroot_retry_after: 60).home_directory)
  end

  # Process helpers (real local processes, no ssh)

  def test_capture3_with_timeout
    out, err, status = adapter.send(:capture3_with_timeout, {}, 'bash', '-c', 'cat; echo err >&2', stdin_data: 'in',
                                                                                              timeout: 5)

    assert_equal(['in', "err\n", true], [out, err, status.success?])
  end

  def test_capture3_with_timeout_kills_slow_commands
    start = Time.now
    error = assert_raises(Timeout::Error) { adapter.send(:capture3_with_timeout, {}, 'sleep', '10', timeout: 1) }

    assert_equal('timed out after 1s', error.message)
    assert_operator(Time.now - start, :<, 5)
  end

  def test_capture3_with_timeout_reads_all_output_of_fast_commands
    20.times do
      out, err, = adapter.send(:capture3_with_timeout, {}, 'bash', '-c', 'echo out; echo err >&2', timeout: 5)

      assert_equal(["out\n", "err\n"], [out, err])
    end
  end

  def test_capture3_with_timeout_reads_large_output
    out, = adapter.send(:capture3_with_timeout, {}, 'head', '-c', '1000000', '/dev/zero', timeout: 5)

    assert_equal(1_000_000, out.bytesize)
  end

  def test_capture3_with_timeout_returns_when_background_process_keeps_output_open
    start = Time.now
    out, err, status = adapter.send(:capture3_with_timeout, {}, 'bash', '-c', 'sleep 3 >/dev/null & echo out; echo err >&2',
                                                     timeout: 10)

    assert_equal(["out\n", "err\n", true], [out, err, status.success?])
    assert_operator(Time.now - start, :<, 2)
  end

  def test_capture3_with_timeout_kills_commands_that_close_output
    start = Time.now
    assert_raises(Timeout::Error) do
      adapter.send(:capture3_with_timeout, {}, 'bash', '-c', 'exec >&- 2>&-; sleep 10', timeout: 1)
    end

    assert_operator(Time.now - start, :<, 5)
  end
end
