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
end