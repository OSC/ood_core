require 'ood_core/job/adapters/helper'

class HelperTest < Minitest::Test

  def helper
    OodCore::Job::Adapters::Helper
  end

  def ssh_prefix(host = 'owens.osc.edu', check = 'yes')
    ['-p', '22', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null',
     '-o', "StrictHostKeyChecking=#{check}", host]
  end

  def test_ssh_wrap_escapes_shell_metacharacters
    cmd, args = helper.ssh_wrap('owens.osc.edu', 'bsub', ['-R', 'select[mem>4000]'])

    assert_equal('ssh', cmd)
    assert_equal(ssh_prefix + ['bsub', '-R', 'select\[mem\>4000\]'], args)
  end

  def test_ssh_wrap_escapes_semicolons
    _cmd, args = helper.ssh_wrap('owens.osc.edu', 'sbatch', ['-J', 'name; rm -rf /tmp/x'])

    assert_includes(args, 'name\;\ rm\ -rf\ /tmp/x')
  end

  def test_ssh_wrap_escapes_env_values_with_spaces
    _cmd, args = helper.ssh_wrap('owens.osc.edu', 'sbatch', [], true, { 'FOO' => 'bar baz' })

    assert_includes(args, 'export FOO=bar\ baz;')
  end

  def test_ssh_wrap_does_not_escape_without_submit_host
    cmd, args = helper.ssh_wrap('', 'bsub', ['-R', 'select[mem>4000]'])

    assert_equal('bsub', cmd)
    assert_equal(['-R', 'select[mem>4000]'], args)
  end
end