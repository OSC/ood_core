require 'test_helper'
require 'ood_core/job/adapters/kubernetes'
require 'ood_core/job/adapters/kubernetes/helper'
require 'ood_core/job/adapters/kubernetes/k8s_job_info'
require 'json'
require 'date'

class TestKubernetesHelper < Minitest::Test
  include TestHelper

  Helper = OodCore::Job::Adapters::Kubernetes::Helper
  K8sJobInfo = OodCore::Job::Adapters::Kubernetes::K8sJobInfo
  Container = OodCore::Job::Adapters::Kubernetes::Resources::Container
  Status = OodCore::Job::Status

  FIXTURES = 'spec/fixtures/output/k8s'

  def setup
    # get_host does a reverse DNS lookup; fail it so the IP is used as-is,
    # which also exercises the rescue path instead of stubbing it away.
    Resolv.stubs(:getname).raises(Resolv::ResolvError)
    @helper = Helper.new
  end

  def fixture(name)
    JSON.parse(File.read("#{FIXTURES}/#{name}.json"), symbolize_names: true)
  end

  def freeze_now(time = '2020-04-18 13:01:56 +0000')
    DateTime.stubs(:now).returns(DateTime.parse(time))
  end

  def pod_hash(id:, state:, job_name:, job_owner:, submission_time:, host:,
               dispatch_time: nil, wallclock_time: nil, procs: nil)
    {
      id: id,
      status: Status.new(state: state),
      job_name: job_name,
      job_owner: job_owner,
      dispatch_time: dispatch_time,
      submission_time: submission_time,
      wallclock_time: wallclock_time,
      ood_connection_info: { host: host },
      procs: procs
    }
  end

  def single_running_pod_hash
    pod_hash(id: 'jupyter-bmurb8sa', state: 'running', job_name: 'jupyter', job_owner: 'johrstrom',
             dispatch_time: 1587060509, submission_time: 1587060496, wallclock_time: 154407,
             host: '10.20.0.40', procs: '1')
  end

  def single_running_pod_not_ready_hash
    pod_hash(id: 'rstudio-server-2cv0zupu', state: 'queued', job_name: 'rstudio-server',
             job_owner: 'user-tdockendorf', submission_time: 1626897251, host: '192.148.247.170', procs: '1')
  end

  def single_error_pod_hash
    pod_hash(id: 'jupyter-h6kw06ve', state: 'suspended', job_name: 'jupyter', job_owner: 'johrstrom',
             submission_time: 1587069112, host: '10.20.0.40')
  end

  def single_image_error_pod_hash
    pod_hash(id: 'jupyter-jhdte09m', state: 'queued', job_name: 'jupyter', job_owner: 'user-tdockendorf',
             submission_time: 1626112960, host: '192.148.247.170', procs: 1)
  end

  def single_crash_loop_pod_hash
    pod_hash(id: 'jupyter-se6t7pfe', state: 'undetermined', job_name: 'jupyter', job_owner: 'user-tdockendorf',
             submission_time: 1626113242, host: '192.148.247.170', procs: 1)
  end

  def single_completed_pod_hash
    pod_hash(id: 'bash', state: 'completed', job_name: 'bash', job_owner: 'johrstrom',
             dispatch_time: 1587506633, submission_time: 1587506632, wallclock_time: 300, host: '10.20.0.40')
  end

  def single_queued_pod_hash
    pod_hash(id: 'jupyter-28wixphq', state: 'queued', job_name: 'jupyter', job_owner: 'johrstrom',
             submission_time: 1587580037, host: '10.20.0.40')
  end

  def single_unscheduleable_pod_hash
    pod_hash(id: 'bash', state: 'queued_held', job_name: 'bash', job_owner: 'johrstrom',
             submission_time: 1587580582, host: nil, procs: '1')
  end

  def ns_prefixed_pod_hash
    pod_hash(id: 'jupyter-3o4n6z3e', state: 'running', job_name: 'jupyter', job_owner: 'johrstrom',
             dispatch_time: 1607638123, submission_time: 1607637118, wallclock_time: 76885,
             host: '192.148.247.227', procs: '1')
  end

  def info_from(pod, service: nil, secret: nil, ns_prefix: nil)
    @helper.info_from_json(
      pod_json: fixture(pod),
      service_json: service && fixture(service),
      secret_json: secret && fixture(secret),
      ns_prefix: ns_prefix
    )
  end

  # ---- info_from_json: one test per recorded pod state ----

  def test_info_from_json_running_pod
    freeze_now
    info = info_from('single_running_pod')

    assert_equal(K8sJobInfo.new(**single_running_pod_hash), info)
    assert(info.status.running?)
  end

  def test_info_from_json_running_pod_not_ready
    freeze_now
    info = info_from('single_running_pod_not_ready')

    assert_equal(K8sJobInfo.new(**single_running_pod_not_ready_hash), info)
    assert(info.status.queued?)
  end

  def test_info_from_json_running_pod_with_service
    freeze_now
    info = info_from('single_running_pod', service: 'single_service')

    expected = single_running_pod_hash
    expected[:ood_connection_info] = { host: '10.20.0.40', port: 30689 }

    assert_equal(K8sJobInfo.new(**expected), info)
    assert(info.status.running?)
  end

  def test_info_from_json_running_pod_with_service_and_secret
    freeze_now
    info = info_from('single_running_pod', service: 'single_service', secret: 'single_secret')

    expected = single_running_pod_hash
    expected[:ood_connection_info] = { host: '10.20.0.40', port: 30689, password: 'ekmfxbOgNUlmLy4m' }

    assert_equal(K8sJobInfo.new(**expected), info)
    assert(info.status.running?)
  end

  def test_info_from_json_errored_pod
    freeze_now
    info = info_from('single_error_pod')

    assert_equal(K8sJobInfo.new(**single_error_pod_hash), info)
    assert(info.status.suspended?)
  end

  def test_info_from_json_image_errored_pod
    freeze_now
    info = info_from('single_image_error_pod')

    assert_equal(K8sJobInfo.new(**single_image_error_pod_hash), info)
    assert(info.status.queued?)
  end

  def test_info_from_json_crash_loop_pod
    freeze_now
    info = info_from('single_crash_loop_pod')

    assert_equal(K8sJobInfo.new(**single_crash_loop_pod_hash), info)
    assert(info.status.undetermined?)
  end

  def test_info_from_json_completed_pod
    freeze_now
    info = info_from('single_completed_pod')

    assert_equal(K8sJobInfo.new(**single_completed_pod_hash), info)
    assert(info.status.completed?)
  end

  def test_info_from_json_queued_pod
    freeze_now
    info = info_from('single_queued_pod')

    assert_equal(K8sJobInfo.new(**single_queued_pod_hash), info)
    assert(info.status.queued?)
  end

  def test_info_from_json_unscheduleable_pod
    freeze_now
    info = info_from('single_unscheduleable_pod')

    assert_equal(K8sJobInfo.new(**single_unscheduleable_pod_hash), info)
    assert(info.status.queued_held?)
  end

  def test_info_from_json_namespace_prefixed_pod
    freeze_now('2020-12-11 14:30:08 -0500')
    info = info_from('ns_prefixed_pod', ns_prefix: 'user-')

    assert_equal(K8sJobInfo.new(**ns_prefixed_pod_hash), info)
  end

  def test_info_from_json_raises_on_bad_data
    empty = {}

    error = assert_raises(Helper::K8sDataError) do
      @helper.info_from_json(pod_json: empty, service_json: empty, secret_json: empty)
    end
    assert_equal('unable to read data correctly from json', error.message)
  end

  def test_info_from_json_skips_secret_values_that_cannot_be_decoded
    freeze_now
    secret = { data: { password: Base64.strict_encode64('ekmfxbOgNUlmLy4m'), broken: 1234 } }

    info = @helper.info_from_json(pod_json: fixture('single_running_pod'), service_json: nil, secret_json: secret)

    assert_equal({ host: '10.20.0.40', password: 'ekmfxbOgNUlmLy4m' }, info.ood_connection_info)
  end

  # ---- pod_info_from_json ----

  def test_pod_info_from_json_running_pod
    freeze_now
    assert_equal(single_running_pod_hash, @helper.pod_info_from_json(fixture('single_running_pod')))
  end

  def test_pod_info_from_json_errored_pod
    freeze_now
    assert_equal(single_error_pod_hash, @helper.pod_info_from_json(fixture('single_error_pod')))
  end

  def test_pod_info_from_json_completed_pod
    freeze_now
    assert_equal(single_completed_pod_hash, @helper.pod_info_from_json(fixture('single_completed_pod')))
  end

  def test_pod_info_from_json_queued_pod
    freeze_now
    assert_equal(single_queued_pod_hash, @helper.pod_info_from_json(fixture('single_queued_pod')))
  end

  def test_pod_info_from_json_unscheduleable_pod
    freeze_now
    assert_equal(single_unscheduleable_pod_hash, @helper.pod_info_from_json(fixture('single_unscheduleable_pod')))
  end

  def test_pod_info_from_json_namespace_prefixed_pod
    freeze_now('2020-12-11 14:30:08 -0500')
    info = @helper.pod_info_from_json(fixture('ns_prefixed_pod'), ns_prefix: 'user-')

    assert_equal(ns_prefixed_pod_hash, info)
  end

  def test_pod_info_from_json_raises_on_bad_data
    error = assert_raises(Helper::K8sDataError) { @helper.pod_info_from_json({}) }
    assert_equal('unable to read data correctly from json', error.message)
  end

  def test_pod_info_from_json_uses_reverse_dns_name_when_it_resolves
    freeze_now
    Resolv.stubs(:getname).with('10.20.0.40').returns('node1.example.com')

    info = @helper.pod_info_from_json(fixture('single_running_pod'))

    assert_equal({ host: 'node1.example.com' }, info[:ood_connection_info])
  end

  # ---- status and timing edge cases not covered by recorded pods ----

  # Smallest pod document pod_info_from_json can read.
  def minimal_pod(status)
    {
      metadata: { name: 'pod-1', namespace: 'someone' },
      spec: { containers: [{ resources: {} }] },
      status: status
    }
  end

  def test_unknown_phase_is_undetermined
    info = @helper.pod_info_from_json(minimal_pod(phase: 'Unknown'))
    assert(info[:status].undetermined?)
  end

  def test_unrecognized_phase_is_undetermined
    info = @helper.pod_info_from_json(minimal_pod(phase: 'SomethingNew'))
    assert(info[:status].undetermined?)
  end

  def test_submission_time_falls_back_to_start_time
    info = @helper.pod_info_from_json(minimal_pod(phase: 'Pending', startTime: '2020-04-18T13:01:56Z'))
    assert_equal(1587214916, info[:submission_time])
  end

  def test_submission_time_falls_back_to_first_condition
    status = { phase: 'Pending', conditions: [{ lastTransitionTime: '2020-04-18T13:01:56Z' }] }
    info = @helper.pod_info_from_json(minimal_pod(status))

    assert_equal(1587214916, info[:submission_time])
  end

  def test_submission_time_is_nil_with_no_time_information
    assert_nil(@helper.pod_info_from_json(minimal_pod(phase: 'Pending'))[:submission_time])
    assert_nil(@helper.pod_info_from_json(minimal_pod(phase: 'Pending', conditions: []))[:submission_time])
    assert_nil(@helper.pod_info_from_json(minimal_pod(phase: 'Pending', conditions: [{}]))[:submission_time])
  end

  def test_millicore_cpu_limits_round_up_to_whole_procs
    pod = minimal_pod(phase: 'Pending')
    pod[:spec][:containers][0][:resources] = { limits: { cpu: '200m' } }

    assert_equal('1', @helper.pod_info_from_json(pod)[:procs])

    pod[:spec][:containers][0][:resources] = { limits: { cpu: '2500m' } }
    assert_equal('3', @helper.pod_info_from_json(pod)[:procs])
  end

  # ---- container_from_native ----

  def ctr_hash
    {
      name: 'ruby-test-container',
      image: 'ruby:2.5',
      command: 'rake spec',
      port: 8080,
      env: { 'HOME' => '/over/here' },
      memory: '12Gi',
      cpu: '6',
      working_dir: '/over/there',
      restart_policy: 'OnFailure',
      image_pull_secret: 'docker-registry-secret'
    }
  end

  def default_env
    { HOME: '/home/test', UID: 1000 }
  end

  # The Container every full-ctr_hash test expects, with overrides.
  def full_container(**overrides)
    Container.new(
      'ruby-test-container',
      'ruby:2.5',
      **{
        port: 8080,
        command: ['rake', 'spec'],
        env: { HOME: '/over/here', UID: 1000 },
        memory_limit: '12Gi',
        memory_request: '12Gi',
        cpu_limit: '6',
        cpu_request: '6',
        working_dir: '/over/there',
        restart_policy: 'OnFailure',
        image_pull_secret: 'docker-registry-secret'
      }.merge(overrides)
    )
  end

  def without(key)
    ctr = ctr_hash
    ctr.delete(key)
    ctr
  end

  def test_container_from_native_full_container
    assert_equal(full_container, @helper.container_from_native(ctr_hash, default_env))
  end

  def test_container_from_native_no_port
    assert_equal(full_container(port: nil), @helper.container_from_native(without(:port), default_env))
  end

  def test_container_from_native_no_command
    assert_equal(full_container(command: []), @helper.container_from_native(without(:command), default_env))
  end

  def test_container_from_native_no_env_uses_default_env
    expected = full_container(env: { HOME: '/home/test', UID: 1000 })
    assert_equal(expected, @helper.container_from_native(without(:env), default_env))
  end

  def test_container_from_native_no_working_dir
    assert_equal(full_container(working_dir: ''), @helper.container_from_native(without(:working_dir), default_env))
  end

  def test_container_from_native_no_restart_policy_defaults_to_never
    expected = full_container(restart_policy: 'Never')
    assert_equal(expected, @helper.container_from_native(without(:restart_policy), default_env))
  end

  def test_container_from_native_no_image_pull_secret
    expected = full_container(image_pull_secret: nil)
    assert_equal(expected, @helper.container_from_native(without(:image_pull_secret), default_env))
  end

  def test_container_from_native_defaults
    ctr = ctr_hash
    ctr[:env] = {}
    ctr[:command] = []
    ctr.delete(:port)
    ctr[:memory_limit] = '4Gi'
    ctr[:memory_request] = '4Gi'
    ctr[:cpu_limit] = '1'
    ctr[:cpu_request] = '1'
    ctr[:restart_policy] = 'Never'
    ctr[:working_dir] = ''
    ctr[:image_pull_secret] = nil

    expected = Container.new('ruby-test-container', 'ruby:2.5', env: { HOME: '/home/test', UID: 1000 })
    assert_equal(expected, @helper.container_from_native(ctr, default_env))
  end

  def test_container_from_native_no_resource_limits
    ctr = ctr_hash
    ctr[:env] = {}
    ctr[:command] = []
    ctr.delete(:port)
    ctr.delete(:cpu)
    ctr.delete(:memory)
    ctr[:restart_policy] = 'Never'
    ctr[:working_dir] = ''
    ctr[:image_pull_secret] = nil

    expected = Container.new(
      'ruby-test-container', 'ruby:2.5',
      env: { HOME: '/home/test', UID: 1000 },
      memory_limit: '4Gi', memory_request: '4Gi', cpu_limit: '1', cpu_request: '1'
    )
    assert_equal(expected, @helper.container_from_native(ctr, default_env))
  end

  def test_container_from_native_explicit_limits_and_requests_win
    ctr = ctr_hash
    ctr[:env] = {}
    ctr[:command] = []
    ctr.delete(:port)
    ctr[:memory] = '9000Gi'
    ctr[:memory_limit] = '8Gi'
    ctr[:memory_request] = '4Gi'
    ctr[:cpu] = '9000'
    ctr[:cpu_limit] = '2'
    ctr[:cpu_request] = '1'
    ctr[:restart_policy] = 'Never'
    ctr[:working_dir] = ''
    ctr[:image_pull_secret] = nil

    expected = Container.new(
      'ruby-test-container', 'ruby:2.5',
      env: { HOME: '/home/test', UID: 1000 },
      memory_limit: '8Gi', memory_request: '4Gi', cpu_limit: '2', cpu_request: '1'
    )
    assert_equal(expected, @helper.container_from_native(ctr, default_env))
  end

  def test_container_from_native_requires_a_name
    error = assert_raises(ArgumentError) { @helper.container_from_native({ image: 'ruby:25' }, default_env) }
    assert_equal('containers need valid names and images', error.message)
  end

  def test_container_from_native_requires_an_image
    error = assert_raises(ArgumentError) { @helper.container_from_native({ name: 'ruby-test-container' }, default_env) }
    assert_equal('containers need valid names and images', error.message)
  end

  # ---- small helpers ----

  def test_parse_command_splits_a_string
    assert_equal(['ls', '-lrt', '/foo/bar'], @helper.parse_command('ls -lrt /foo/bar'))
  end

  def test_parse_command_respects_quotes
    assert_equal(['ls', '-lrt', '/foo/bar', '/dir/with/a space'],
                 @helper.parse_command("ls -lrt /foo/bar '/dir/with/a space'"))
  end

  def test_parse_command_returns_arrays_unchanged
    arr = ['ls', '-lrt', '/foo/bar']
    assert_equal(arr, @helper.parse_command(arr))
  end

  def test_parse_command_accepts_nil
    assert_equal([], @helper.parse_command(nil))
  end

  def test_seconds_to_duration
    assert_equal('01h00m00s', @helper.seconds_to_duration(3600))
    assert_equal('01h01m00s', @helper.seconds_to_duration(3660))
    assert_equal('01h01m02s', @helper.seconds_to_duration(3662))
  end
end
