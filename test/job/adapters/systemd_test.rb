require 'test_helper'

class SystemdTest < Minitest::Test
  include TestHelper

  def systemd_instance(config = { })
    OodCore::Job::Factory.build({ adapter: 'systemd' }.merge(config))
  end

  def test_instantiation
    sysd = systemd_instance

    refute_nil(sysd)
  end
end