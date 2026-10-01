require 'test_helper'
require 'ood_core/job/adapters/kubernetes'

class TestKubernetes < Minitest::Test
  include TestHelper

  Kubernetes = OodCore::Job::Adapters::Kubernetes
  Batch = OodCore::Job::Adapters::Kubernetes::Batch

  def adapter(batch = mock('batch'))
    Kubernetes.new(batch)
  end

  def job(id, owner)
    OodCore::Job::Info.new(id: id, status: 'running', job_owner: owner)
  end

  # ---- interface ----

  def test_submit_interface
    k8s = adapter
    verify_args(k8s, :submit, 1)
    veryify_keywords(k8s, :submit, [:after, :afterok, :afternotok, :afterany])
  end

  def test_info_all_interface
    k8s = adapter
    verify_args(k8s, :info_all, 0)
    veryify_keywords(k8s, :info_all, [:attrs])
  end

  def test_info_where_owner_interface
    k8s = adapter
    verify_args(k8s, :info_where_owner, 1)
    veryify_keywords(k8s, :info_where_owner, [:attrs])
  end

  def test_single_job_interfaces
    k8s = adapter
    [:info, :status, :hold, :release, :delete].each do |method|
      verify_args(k8s, method, 1)
    end
    verify_args(k8s, :directive_prefix, 0)
  end

  def test_factory_builds_a_configured_adapter
    k8s = OodCore::Job::Factory.build({ adapter: 'kubernetes', 'bin' => '/opt/kubectl', 'cluster' => 'test' })

    assert_instance_of(Kubernetes, k8s)
    assert_equal('/opt/kubectl', k8s.batch.bin)
    assert_equal('test', k8s.batch.cluster)
  end

  # ---- unsupported features ----

  def test_does_not_support_job_arrays
    refute(adapter.supports_job_arrays?)
  end

  def test_does_not_support_hold
    error = assert_raises(NotImplementedError) { adapter.hold('123') }
    assert_equal('subclass did not define #hold', error.message)
  end

  def test_does_not_support_release
    error = assert_raises(NotImplementedError) { adapter.release('123') }
    assert_equal('subclass did not define #release', error.message)
  end

  # ---- delegation to Batch ----

  def test_submit
    script = build_script
    batch = mock('batch')
    batch.expects(:submit).with(script).returns('pod-123')

    assert_equal('pod-123', adapter(batch).submit(script))
  end

  def test_submit_requires_a_script
    assert_raises(ArgumentError) { adapter.submit(nil) }
  end

  def test_info
    info = job('pod-123', 'me')
    batch = mock('batch')
    batch.expects(:info).with('pod-123').returns(info)

    assert_equal(info, adapter(batch).info(:'pod-123'))
  end

  def test_status
    batch = mock('batch')
    batch.expects(:info).with('pod-123').returns(job('pod-123', 'me'))

    assert(adapter(batch).status('pod-123').running?)
  end

  def test_delete
    batch = mock('batch')
    batch.expects(:delete).with('pod-123')

    adapter(batch).delete(:'pod-123')
  end

  def test_batch_errors_become_job_adapter_errors
    error = Batch::Error.new('kubectl blew up')
    batch = stub('batch')
    batch.stubs(:submit).raises(error)
    batch.stubs(:info).raises(error)
    batch.stubs(:info_all).raises(error)
    batch.stubs(:delete).raises(error)
    k8s = adapter(batch)

    [
      -> { k8s.submit(build_script) },
      -> { k8s.info('pod-123') },
      -> { k8s.info_all },
      -> { k8s.delete('pod-123') }
    ].each do |call|
      raised = assert_raises(OodCore::JobAdapterError) { call.call }
      assert_equal('kubectl blew up', raised.message)
    end
  end

  # ---- owner filtering and enumeration ----

  def jobs
    [job('a', 'me'), job('b', 'you'), job('c', 'me')]
  end

  def test_info_all_passes_attrs_through
    batch = mock('batch')
    batch.expects(:info_all).with(attrs: [:id]).returns(jobs)

    assert_equal(jobs, adapter(batch).info_all(attrs: [:id]))
  end

  def test_info_where_owner_filters_by_owner
    batch = mock('batch')
    batch.expects(:info_all).with(attrs: nil).returns(jobs)

    assert_equal(['a', 'c'], adapter(batch).info_where_owner('me').map(&:id))
  end

  def test_info_where_owner_accepts_several_owners
    batch = mock('batch')
    batch.expects(:info_all).with(attrs: nil).returns(jobs)

    assert_equal(['a', 'b', 'c'], adapter(batch).info_where_owner(['me', :you]).map(&:id))
  end

  def test_info_where_owner_always_requests_job_owner
    batch = mock('batch')
    batch.expects(:info_all).with(attrs: [:id, :job_owner]).returns(jobs)

    adapter(batch).info_where_owner('me', attrs: [:id])
  end

  def test_info_all_each
    batch = stub('batch', info_all: jobs)
    k8s = adapter(batch)

    assert_equal(jobs, k8s.info_all_each.to_a)

    yielded = []
    k8s.info_all_each { |info| yielded << info.id }
    assert_equal(['a', 'b', 'c'], yielded)
  end

  def test_info_where_owner_each
    batch = stub('batch', info_all: jobs)
    k8s = adapter(batch)

    assert_equal(['b'], k8s.info_where_owner_each('you').map(&:id))

    yielded = []
    k8s.info_where_owner_each('me') { |info| yielded << info.id }
    assert_equal(['a', 'c'], yielded)
  end
end
