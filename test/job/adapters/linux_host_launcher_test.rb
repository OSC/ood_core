require 'test_helper'
require 'ood_core/job/adapters/linux_host'
require 'ood_core/job/adapters/linux_host/launcher'

class LinuxHostLauncherTest < Minitest::Test
  include TestHelper

  def launcher_instance(config = {})
    default = { 
                singularity_image: '/dev/null', singularity_bin: '/usr/bin/singularity',
                ssh_hosts: ['example.edu'], tmux_bin: '/usr/bin/tmux', submit_host: 'example.edu'
              }
    OodCore::Job::Adapters::LinuxHost::Launcher.new(**default.merge(config))
  end

  def test_instantiation
    launcher = launcher_instance

    refute_nil(launcher)
  end

  def test_submit_host_override_works
    launcher = launcher_instance
    script = build_script(native: { submit_host_override: 'oakley.osc.edu' })

    refute_nil(launcher)
    assert_equal('oakley.osc.edu', launcher.submit_host(script))
  end

  def test_submit_host_override_defaults_submit_host
    launcher = launcher_instance
    script = build_script

    refute_nil(launcher)
    assert_equal('example.edu', launcher.submit_host(script))
  end
end
