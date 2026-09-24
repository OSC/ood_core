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

  def test_submit_raises_when_hostname_cannot_be_parsed
    adapter = systemd_instance(submit_host: 'localhost')
    Etc.stubs(:getlogin).returns('testuser')
    Open3.stubs(:capture3).returns(['no hostname line here', '', exit_success])

    error = assert_raises(OodCore::JobAdapterError) do
      adapter.submit(build_script)
    end

    assert_match(/hostname/i, error.message)
  end

  def test_site_timeout_config_reaches_launcher
    adapter = systemd_instance(submit_host: 'localhost', site_timeout: 5678)
    launcher = adapter.instance_variable_get(:@launcher)

    assert_equal(5678, launcher.site_timeout)
  end

  def test_max_timeout_config_still_accepted
    adapter = systemd_instance(submit_host: 'localhost', max_timeout: 1234)
    launcher = adapter.instance_variable_get(:@launcher)

    assert_equal(1234, launcher.site_timeout)
  end

  def test_site_timeout_wins_over_max_timeout
    adapter = systemd_instance(submit_host: 'localhost', site_timeout: 5678, max_timeout: 1234)
    launcher = adapter.instance_variable_get(:@launcher)

    assert_equal(5678, launcher.site_timeout)
  end

  def test_timeout_defaults_to_zero_when_unset
    adapter = systemd_instance(submit_host: 'localhost')
    launcher = adapter.instance_variable_get(:@launcher)

    assert_equal(0, launcher.site_timeout)
  end
end
