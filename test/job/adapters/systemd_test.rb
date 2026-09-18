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

  def test_does_not_support_job_dependencies
    refute(systemd_instance.supports_job_dependencies?)
  end
end
