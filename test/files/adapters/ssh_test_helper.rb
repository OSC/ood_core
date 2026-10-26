require 'test_helper'
require 'ood_core/files/adapters/ssh'
require 'climate_control'

# Shared helpers for the ssh files adapter tests.
module SshTestHelper
  FAKE_SSH = File.expand_path('../../fixtures/scripts/fake_ssh', __dir__)

  def ssh_adapter(host: 'fakehost', bin_overrides: {}, cluster_id: 'test', **opts)
    OodCore::Files::Adapters::Ssh.new(host: host, bin_overrides: bin_overrides, cluster_id: cluster_id, **opts)
  end

  def exit_status(code)
    OpenStruct.new(:success? => code.zero?, :exitstatus => code)
  end
end
