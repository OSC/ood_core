require 'test_helper'
require 'json'
require 'ood_core/job/adapters/kubernetes'
require 'ood_core/job/adapters/kubernetes/helper'

# wallclock_limit comes from the pod.kubernetes.io/lifetime annotation, which
# holds a Go duration string (ood_core#232).
class KubernetesHelperTest < Minitest::Test
  include TestHelper

  def helper
    @helper ||= OodCore::Job::Adapters::Kubernetes::Helper.new
  end

  def test_duration_to_seconds_reverses_seconds_to_duration
    [0, 59, 3600, 5400, 86_399, 360_000].each do |seconds|
      duration = helper.seconds_to_duration(seconds)
      assert_equal(seconds, helper.duration_to_seconds(duration), duration)
    end
  end

  # Anything Go's time.ParseDuration accepts, since that's what the pod
  # reaper uses and a pod's annotation may not have come from ood_core.
  def test_duration_to_seconds_reads_go_durations
    {
      '24h' => 86_400,
      '90m' => 5400,
      '1h30m' => 5400,
      '1.5h' => 5400,
      '0.7h' => 2520,
      '0.565h' => 2034, # 2033.999... in floating point, which floors to 2033

      '2m30.5s' => 150,
      '1500ms' => 1,
      '+1h' => 3600,
      '0' => 0
    }.each do |duration, seconds|
      assert_equal(seconds, helper.duration_to_seconds(duration), duration)
    end
  end

  def test_duration_to_seconds_returns_nil_for_anything_else
    [nil, '', '1d', 'abc', '-1h', '1h junk', 'h', '1.5', '1h 30m'].each do |duration|
      assert_nil(helper.duration_to_seconds(duration), duration.inspect)
    end
  end

  def test_pod_info_reports_the_lifetime_as_wallclock_limit
    pod = pod_with_lifetime('24h')

    assert_equal(86_400, helper.pod_info_from_json(pod)[:wallclock_limit])
  end

  def test_pod_info_has_no_wallclock_limit_without_a_lifetime
    pod = pod_with_lifetime(nil)

    assert_nil(helper.pod_info_from_json(pod)[:wallclock_limit])
  end

  def test_wallclock_limit_reaches_the_job_info
    info = OodCore::Job::Adapters::Kubernetes::K8sJobInfo.new(**helper.pod_info_from_json(pod_with_lifetime('2h')))

    assert_equal(7200, info.wallclock_limit)
  end

  private

  # A real pod from kubectl, with its lifetime annotation replaced.
  def pod_with_lifetime(lifetime)
    helper.stubs(:get_host).returns('10.20.0.40')
    pod = JSON.parse(File.read('spec/fixtures/output/k8s/single_running_pod_not_ready.json'), symbolize_names: true)
    annotations = pod[:metadata][:annotations]
    annotations.delete(:'pod.kubernetes.io/lifetime')
    annotations[:'pod.kubernetes.io/lifetime'] = lifetime unless lifetime.nil?
    pod
  end
end
