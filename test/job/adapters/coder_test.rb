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

  def test_build_coder_with_cloud_none
    adapter = OodCore::Job::Factory.build(
      'adapter' => 'coder',
      'host' => 'https://coder.example.com',
      'token' => 'fake-token',
      'service_user' => 'ood',
      'auth' => { 'cloud' => 'none' }
    )

    assert_instance_of(OodCore::Job::Adapters::Coder, adapter)
  end

  def test_build_coder_without_auth_block
    adapter = OodCore::Job::Factory.build(
      'adapter' => 'coder',
      'host' => 'https://coder.example.com',
      'token' => 'fake-token',
      'service_user' => 'ood'
    )

    assert_instance_of(OodCore::Job::Adapters::Coder, adapter)
  end

  def test_build_coder_rejects_unknown_cloud
    error = assert_raises(ArgumentError) do
      OodCore::Job::Factory.build(
        'adapter' => 'coder',
        'host' => 'https://coder.example.com',
        'token' => 'fake-token',
        'service_user' => 'ood',
        'auth' => { 'cloud' => 'not-a-cloud' }
      )
    end

    assert_match(/not-a-cloud/, error.message)
  end

  def test_openstack_creds_from_config
    Dir.mktmpdir do |dir|
      cfg = <<~HEREDOC
        ---
        v2:
          job:
            adapter: coder
            auth:
              cloud: openstack
              dir: /some/fake/directory
              auth_url: http://some.auth.url/test
      HEREDOC

      Pathname.new("#{dir}/coder.yml").write(cfg)

      adapter = OodCore::Clusters.load_file(dir)['coder'].job_adapter
      batch = adapter.instance_variable_get(:@batch)
      creds = batch.instance_variable_get(:@credentials)

      assert_instance_of(OodCore::Job::Adapters::Coder, adapter)
      assert_instance_of(OpenstackCredentials, creds)

      creds_auth_url = creds.instance_variable_get(:@auth_url)
      creds_dir = creds.instance_variable_get(:@dir)

      assert_equal('http://some.auth.url/test', creds_auth_url)
      assert_equal('/some/fake/directory', creds_dir)
    end
  end

  def test_none_creds_from_config
    Dir.mktmpdir do |dir|
      cfg = <<~HEREDOC
        ---
        v2:
          job:
            adapter: coder
            auth:
              cloud: none
      HEREDOC

      Pathname.new("#{dir}/coder.yml").write(cfg)

      adapter = OodCore::Clusters.load_file(dir)['coder'].job_adapter
      batch = adapter.instance_variable_get(:@batch)
      creds = batch.instance_variable_get(:@credentials)

      assert_instance_of(OodCore::Job::Adapters::Coder, adapter)
      assert_instance_of(NoneCredentials, creds)
    end
  end

  def test_new_creds_from_config
    Dir.mktmpdir do |dir|
      cfg = <<~HEREDOC
        ---
        v2:
          job:
            adapter: coder
            auth:
              cloud: user_defined_test
      HEREDOC

      auth = <<~HEREDOC
        class UserDefinedTestCredentials < CredentialsInterface

          # only need to define the initializer bc that's the only bit being
          # called in this test
          def initialize(**kwargs) end
        end
      HEREDOC

      Pathname.new("#{dir}/coder.yml").write(cfg)
      Pathname.new("#{dir}/user_defined_test_credentials.rb").write(auth)

      # credential authors will have to require & load the ruby file in question
      require "#{dir}/user_defined_test_credentials.rb"

      adapter = OodCore::Clusters.load_file(dir)['coder'].job_adapter
      batch = adapter.instance_variable_get(:@batch)
      creds = batch.instance_variable_get(:@credentials)

      assert_instance_of(OodCore::Job::Adapters::Coder, adapter)
      assert_instance_of(UserDefinedTestCredentials, creds)
    end
  end
end
