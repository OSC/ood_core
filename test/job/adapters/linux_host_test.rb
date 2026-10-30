require 'test_helper'

class LinuxHostTest < Minitest::Test
  include TestHelper

  def linux_host_instance(config = { singularity_image: '/dev/null' })
    OodCore::Job::Factory.build({ adapter: 'linux_host' }.merge(config))
  end

  def test_instantiation
    lha = linux_host_instance

    refute_nil(lha)
  end

  def test_ssh_port_is_passed_to_ssh
    Etc.stubs(:getpwuid).returns(OpenStruct.new(name: 'testuser'))
    lha = linux_host_instance({ singularity_image: '/dev/null', ssh_port: 2222 })
    launcher = lha.instance_variable_get(:@launcher)
    expected = ['ssh', '-t', '-p', '2222', '-o', 'BatchMode=yes', 'testuser@localhost', '/bin/bash']

    assert_equal(expected, launcher.send(:ssh_cmd, 'localhost', ['/bin/bash']))
  end
end
