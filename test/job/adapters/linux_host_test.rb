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
end