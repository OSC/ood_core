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
end
