require 'test_helper'
require 'ood_core/job/adapters/htcondor'

# script.native and script.cores are both optional, so submitting without
# either has to work.
class HTCondorTest < Minitest::Test
  include TestHelper

  def test_submits_without_native
    args = submit_args(cores: 4)

    assert_includes(args, 'request_cpus=4')
    assert_includes(args, 'request_memory=4096')
    assert_includes(args, 'universe=vanilla')
  end

  def test_submits_without_cores
    args = submit_args(native: {})

    refute_includes(args, 'request_cpus')
    refute_includes(args, 'request_memory')
  end

  def test_request_memory_from_native_wins_over_cores
    args = submit_args(cores: 4, native: { request_memory: 2048 })

    assert_includes(args, '-a request_memory=2048')
    refute_includes(args, 'request_memory=4096')
  end

  def test_docker_universe_without_native
    args = submit_args({ cores: 1 }, default_universe: 'docker')

    assert_includes(args, 'universe=docker')
    assert_includes(args, 'docker_image=ubuntu:latest')
  end

  def test_container_universe_without_native
    args = submit_args({ cores: 1 }, default_universe: 'container', default_docker_image: 'rocky:9')

    assert_includes(args, 'universe=container')
    assert_includes(args, '-a container_image=rocky:9')
  end

  private

  # The condor_submit arguments, joined into one string
  def submit_args(script_opts = {}, adapter_opts = {})
    OodCore::Job::Adapters::HTCondor::Batch.any_instance.stubs(:get_htcondor_version).returns(Gem::Version.new('24.0.0'))
    adapter = OodCore::Job::Factory.build({ adapter: 'htcondor' }.merge(adapter_opts))

    args = nil
    OodCore::Job::Adapters::HTCondor::Batch.any_instance.stubs(:submit_string).with do |**kwargs|
      args = kwargs[:args].join(' ')
    end.returns('1')

    adapter.submit(OodCore::Job::Script.new(content: 'hostname', **script_opts))
    args
  end
end
