require 'test_helper'
require 'ood_core/job/adapters/coder'
require 'ood_core/job/adapters/coder/batch'

class CoderTest < Minitest::Test
  include TestHelper

  def credentials
    stub()
  end

  def batch(config = {})
    OodCore::Job::Adapters::Coder::Batch.new(
      {
        host: 'https://coder.example.com',
        token: 'fake-token',
        service_user: 'ood'
      }.merge(config),
      credentials
    )
  end

  def workspace_info(metadata)
    {
      'id' => 'abc-123',
      'workspace_name' => 'test-workspace',
      'workspace_owner_name' => 'ood',
      'created_at' => '2026-01-01T00:00:00Z',
      'updated_at' => '2026-01-01T00:00:00Z',
      'latest_build' => {
        'id' => 'build-1',
        'status' => 'running',
        'updated_at' => '2026-01-01T00:00:00Z',
        'resources' => [
          { 'name' => 'coder_output', 'metadata' => metadata }
        ]
      }
    }
  end

  def test_info_uses_port_from_coder_output_metadata
    coder = batch
    coder.stubs(:get_build_logs).returns([])
    coder.stubs(:get_workspace_info).returns(
      workspace_info(
        [
          { 'key' => 'floating_ip', 'value' => '10.0.0.5' },
          { 'key' => 'port', 'value' => '13337' }
        ]
      )
    )

    assert_equal(13337, coder.info('abc-123').ood_connection_info[:port])
  end

  def test_info_defaults_to_port_80
    coder = batch
    coder.stubs(:get_build_logs).returns([])
    coder.stubs(:get_workspace_info).returns(
      workspace_info(
        [
          { 'key' => 'floating_ip', 'value' => '10.0.0.5' }
        ]
      )
    )

    assert_equal(80, coder.info('abc-123').ood_connection_info[:port])
  end
end
