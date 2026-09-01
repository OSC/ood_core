require 'test_helper'
require 'ood_core/job/adapters/systemd'
require 'ood_core/job/adapters/systemd/launcher'

class SystemdLauncherTest < Minitest::Test
  include TestHelper

  def launcher_instance(config = {})
    default = { ssh_hosts: ['foo'], submit_host: 'localhost' }
    OodCore::Job::Adapters::LinuxSystemd::Launcher.new(**default.merge(config))
  end

  def setup
    Etc.stubs(:getlogin).returns('testuser')
  end

  def test_instantiation
    launcher = launcher_instance

    refute_nil(launcher)
  end

  def test_ssh_cmd_default
    launcher = launcher_instance
    expected = [  'ssh', '-t', '-p', '22', '-o',
                  'Batchmode=yes', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
                  'testuser@localhost', '/bin/bash'
                ]

    assert_equal(expected, launcher.send(:ssh_cmd, 'localhost', ['/bin/bash']))
  end

  def test_ssh_cmd_with_host_checking
    launcher = launcher_instance({ strict_host_checking: true })
    expected = [  'ssh', '-t', '-p', '22', '-o',
                  'Batchmode=yes', 'testuser@localhost', '/bin/bash'
                ]

    assert_equal(expected, launcher.send(:ssh_cmd, 'localhost', ['/bin/bash']))
  end

  def test_ssh_cmd_with_keyfile
    launcher = launcher_instance({ ssh_keyfile: "~/.ssh/my_key" })
    expected = [  'ssh', '-t', '-p', '22', '-o',
                  'Batchmode=yes', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
                  '-i', '~/.ssh/my_key', 'testuser@localhost', '/bin/bash'
                ]

    assert_equal(expected, launcher.send(:ssh_cmd, 'localhost', ['/bin/bash']))
  end

  # #script_timeout

  def test_script_timeout_infinity_when_no_timeouts_set
    launcher = launcher_instance({ site_timeout: 0 })

    assert_equal('infinity', launcher.send(:script_timeout, build_script(wall_time: 0)))
  end

  def test_script_timeout_wall_time_when_no_site_timeout
    launcher = launcher_instance({ site_timeout: 0 })

    assert_equal(1, launcher.send(:script_timeout, build_script(wall_time: 1)))
  end

  def test_script_timeout_site_timeout_when_less_than_wall_time
    launcher = launcher_instance({ site_timeout: 200 })

    assert_equal(200, launcher.send(:script_timeout, build_script(wall_time: 300)))
  end

  def test_script_timeout_wall_time_when_less_than_site_timeout
    launcher = launcher_instance({ site_timeout: 200 })

    assert_equal(100, launcher.send(:script_timeout, build_script(wall_time: 100)))
  end

  def test_script_timeout_site_timeout_when_wall_time_is_zero
    launcher = launcher_instance({ site_timeout: 200 })

    assert_equal(200, launcher.send(:script_timeout, build_script(wall_time: 0)))
  end

  def test_script_timeout_treats_nil_wall_time_as_zero
    launcher = launcher_instance({ site_timeout: 200 })

    assert_equal(200, launcher.send(:script_timeout, build_script))
  end

  # #parse_hostname

  def test_parse_hostname_reads_hostname_line
    launcher = launcher_instance
    output = "blah noise\nHOSTNAME:owens-login01.hpc.osc.edu\nmore noise blah"

    assert_equal('owens-login01.hpc.osc.edu', launcher.send(:parse_hostname, output))
  end

  def test_parse_hostname_takes_last_when_multiple
    launcher = launcher_instance
    output = "blah\nHOSTNAME:owens-login01.hpc.osc.edu\nblah\nHOSTNAME:owens-login02.hpc.osc.edu\nblah"

    assert_equal('owens-login02.hpc.osc.edu', launcher.send(:parse_hostname, output))
  end

  def test_parse_hostname_empty_when_hostname_has_no_value
    launcher = launcher_instance
    output = "blah\nHOSTNAME:\nblah"

    assert_equal('', launcher.send(:parse_hostname, output))
  end

  def test_parse_hostname_empty_when_hostname_absent
    launcher = launcher_instance
    output = "blah\nblah\nblah"

    assert_equal('', launcher.send(:parse_hostname, output))
  end

  # #user_script_has_shebang?

  def test_user_script_has_shebang_true_for_shebang
    launcher = launcher_instance
    script = build_script(content: "#!/bin/bash\necho test")

    assert_equal(true, launcher.send(:user_script_has_shebang?, script))
  end

  def test_user_script_has_shebang_false_for_empty_content
    launcher = launcher_instance
    script = build_script(content: '')

    assert_equal(false, launcher.send(:user_script_has_shebang?, script))
  end

  def test_user_script_has_shebang_false_when_not_first_line
    launcher = launcher_instance
    script = build_script(content: "echo test\n#!/bin/bash")

    assert_equal(false, launcher.send(:user_script_has_shebang?, script))
  end

  # #script_arguments

  def test_script_arguments_empty_when_args_nil
    launcher = launcher_instance

    assert_equal('', launcher.send(:script_arguments, build_script))
  end

  def test_script_arguments_empty_when_args_empty
    launcher = launcher_instance

    assert_equal('', launcher.send(:script_arguments, build_script(args: [])))
  end

  def test_script_arguments_joins_multiple_args
    launcher = launcher_instance
    script = build_script(args: ['--verbose', '--output', 'file.txt'])

    assert_equal('--verbose --output file.txt', launcher.send(:script_arguments, script))
  end

  def test_script_arguments_escapes_spaces
    launcher = launcher_instance
    script = build_script(args: ['my file.txt'])

    assert_equal('my\ file.txt', launcher.send(:script_arguments, script))
  end

  # #export_env

  def test_export_env_empty_when_environment_nil
    launcher = launcher_instance

    assert_equal('', launcher.send(:export_env, build_script))
  end

  def test_export_env_builds_export_line
    launcher = launcher_instance
    script = build_script(job_environment: { 'FOO' => 'bar' })

    assert_equal('export FOO=bar', launcher.send(:export_env, script))
  end

  def test_export_env_sorts_lines
    launcher = launcher_instance
    script = build_script(job_environment: { 'ZED' => '1', 'ALPHA' => '2' })

    assert_equal("export ALPHA=2\nexport ZED=1", launcher.send(:export_env, script))
  end

  def test_export_env_escapes_values_with_spaces
    launcher = launcher_instance
    script = build_script(job_environment: { 'MSG' => 'hello world' })

    assert_equal('export MSG=hello\ world', launcher.send(:export_env, script))
  end

  # #error_path

  def test_error_path_uses_error_path
    launcher = launcher_instance
    script = build_script(error_path: '/tmp/err.log')

    assert_equal('/tmp/err.log', launcher.send(:error_path, script))
  end

  def test_error_path_falls_back_to_output_path
    launcher = launcher_instance
    script = build_script(output_path: '/tmp/out.log')

    assert_equal('/tmp/out.log', launcher.send(:error_path, script))
  end

  def test_error_path_prefers_error_path_over_output_path
    launcher = launcher_instance
    script = build_script(error_path: '/tmp/err.log', output_path: '/tmp/out.log')

    assert_equal('/tmp/err.log', launcher.send(:error_path, script))
  end

  def test_error_path_defaults_to_dev_null
    launcher = launcher_instance

    assert_equal('/dev/null', launcher.send(:error_path, build_script))
  end

  def test_error_path_returns_a_string
    launcher = launcher_instance
    script = build_script(error_path: '/tmp/err.log')

    assert_instance_of(String, launcher.send(:error_path, script))
  end

  # #unique_session_name

  def test_unique_session_name_uses_label_prefix
    launcher = launcher_instance

    assert(launcher.send(:unique_session_name).start_with?('ondemand-'))
  end

  def test_unique_session_name_appends_ten_alphanumeric_characters
    launcher = launcher_instance

    assert_match(/\Aondemand-[a-zA-Z0-9]{10}\z/, launcher.send(:unique_session_name))
  end

  def test_unique_session_name_differs_between_calls
    launcher = launcher_instance

    refute_equal(launcher.send(:unique_session_name), launcher.send(:unique_session_name))
  end

  # #submit_host

  def test_submit_host_without_script
    launcher = launcher_instance

    assert_equal('localhost', launcher.submit_host)
  end

  def test_submit_host_with_script_lacking_native
    launcher = launcher_instance

    assert_equal('localhost', launcher.submit_host(build_script))
  end

  def test_submit_host_with_native_lacking_override
    launcher = launcher_instance
    script = build_script(native: { 'something_else' => 'value' })

    assert_equal('localhost', launcher.submit_host(script))
  end

  def test_submit_host_with_override
    launcher = launcher_instance
    script = build_script(native: { 'submit_host_override' => 'other.osc.edu' })

    assert_equal('other.osc.edu', launcher.submit_host(script))
  end
end