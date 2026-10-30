require 'ood_core/job/adapters/helper'

class HelperTest < Minitest::Test

  def helper
    OodCore::Job::Adapters::Helper
  end

  def ssh_prefix(host = 'owens.osc.edu', check = 'yes')
    ['-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null',
     '-o', "StrictHostKeyChecking=#{check}", host]
  end

  def with_ood_ssh_port(port)
    old = ENV['OOD_SSH_PORT']
    ENV['OOD_SSH_PORT'] = port
    yield
  ensure
    ENV['OOD_SSH_PORT'] = old
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

  def test_ssh_wrap_leaves_out_port_without_ssh_port_or_ood_ssh_port
    with_ood_ssh_port(nil) do
      _cmd, args = helper.ssh_wrap('owens.osc.edu', 'sbatch', [])

      assert_equal(ssh_prefix + ['sbatch'], args)
    end
  end

  def test_ssh_wrap_uses_ood_ssh_port
    with_ood_ssh_port('1022') do
      _cmd, args = helper.ssh_wrap('owens.osc.edu', 'sbatch', [])

      assert_equal(['-p', '1022'] + ssh_prefix + ['sbatch'], args)
    end
  end

  def test_ssh_wrap_uses_ssh_port
    with_ood_ssh_port(nil) do
      _cmd, args = helper.ssh_wrap('owens.osc.edu', 'sbatch', [], true, { 'FOO' => 'bar' }, ssh_port: 2222)

      assert_equal(['-p', '2222'] + ssh_prefix + ['export FOO=bar;', 'sbatch'], args)
    end
  end

  def test_ssh_port_takes_precedence_over_ood_ssh_port
    with_ood_ssh_port('1022') do
      _cmd, args = helper.ssh_wrap('owens.osc.edu', 'sbatch', [], ssh_port: '2222')

      assert_equal(['-p', '2222'] + ssh_prefix + ['sbatch'], args)
    end
  end

  def test_empty_ssh_port_falls_back_to_ood_ssh_port
    with_ood_ssh_port('1022') do
      assert_equal(['-p', '1022'], helper.ssh_port_args(''))
    end
  end

  def test_ssh_wrap_does_not_escape_without_submit_host
    cmd, args = helper.ssh_wrap('', 'bsub', ['-R', 'select[mem>4000]'])

    assert_equal('bsub', cmd)
    assert_equal(['-R', 'select[mem>4000]'], args)
  end
end