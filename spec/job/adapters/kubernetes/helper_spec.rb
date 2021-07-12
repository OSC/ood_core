require "ood_core/job/adapters/kubernetes"
require "ood_core/job/adapters/kubernetes/helper"
require "ood_core/job/adapters/kubernetes/k8s_job_info"
require "json"
require "date"

using OodCore::Refinements::HashExtensions

describe OodCore::Job::Adapters::Kubernetes::Helper do
  subject(:helper){
    helper = described_class.new
    allow(helper).to receive(:get_host).with(nil).and_return(nil)
    allow(helper).to receive(:get_host).with('10.20.0.40').and_return('10.20.0.40')
    allow(helper).to receive(:get_host).with('192.148.247.227').and_return('192.148.247.227')
    allow(helper).to receive(:get_host).with('192.148.247.170').and_return('192.148.247.170')
    helper
  }

  let(:single_running_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_running_pod.json'), symbolize_names: true) }
  let(:single_error_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_error_pod.json'), symbolize_names: true) }
  let(:single_image_error_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_image_error_pod.json'), symbolize_names: true) }
  let(:single_crash_loop_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_crash_loop_pod.json'), symbolize_names: true) }
  let(:single_completed_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_completed_pod.json'), symbolize_names: true) }
  let(:single_queued_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_queued_pod.json'), symbolize_names: true) }
  let(:single_unscheduleable_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/single_unscheduleable_pod.json'), symbolize_names: true) }
  let(:single_service) { JSON.parse(File.read('spec/fixtures/output/k8s/single_service.json'), symbolize_names: true) }
  let(:single_secret) { JSON.parse(File.read('spec/fixtures/output/k8s/single_secret.json'), symbolize_names: true) }
  let(:ns_prefixed_pod) { JSON.parse(File.read('spec/fixtures/output/k8s/ns_prefixed_pod.json'), symbolize_names: true) }
  let(:now) { DateTime.parse("2020-04-18 13:01:56 +0000") }

  let(:single_running_pod_hash) {{
    id: "jupyter-bmurb8sa",
    status: OodCore::Job::Status.new(state: "running"),
    job_name: "jupyter",
    job_owner: "johrstrom",
    dispatch_time: 1587060509,
    submission_time: 1587060496,
    wallclock_time: 154407,
    ood_connection_info: { host: "10.20.0.40" },
    procs: "1"
  }}

  let(:single_error_pod_hash) {{
    id: "jupyter-h6kw06ve",
    status: OodCore::Job::Status.new(state: "suspended"),
    job_name: "jupyter",
    job_owner: "johrstrom",
    dispatch_time: nil,
    submission_time: 1587069112,
    wallclock_time: nil,
    ood_connection_info: { host: "10.20.0.40" },
    procs: nil
  }}

  let(:single_image_error_pod_hash) {{
    id: "jupyter-jhdte09m",
    status: OodCore::Job::Status.new(state: "queued"),
    job_name: "jupyter",
    job_owner: "user-tdockendorf",
    dispatch_time: nil,
    submission_time: 1626112960,
    wallclock_time: nil,
    ood_connection_info: { host: "192.148.247.170" },
    procs: 1
  }}

  let(:single_crash_loop_pod_hash) {{
    id: "jupyter-h6kw06ve",
    status: OodCore::Job::Status.new(state: "undetermined"),
    job_name: "jupyter",
    job_owner: "johrstrom",
    dispatch_time: nil,
    submission_time: 1587069112,
    wallclock_time: nil,
    ood_connection_info: { host: "10.20.0.40" },
    procs: nil
  }}

  let(:single_completed_pod_hash) {{
    id: "bash",
    status: OodCore::Job::Status.new(state: "completed"),
    job_name: "bash",
    job_owner: "johrstrom",
    dispatch_time: 1587506633,
    submission_time: 1587506632,
    wallclock_time: 300,
    ood_connection_info: { host: "10.20.0.40" },
    procs: nil
  }}

  let(:single_queued_pod_hash) {{
    id: "jupyter-28wixphq",
    status: OodCore::Job::Status.new(state: "queued"),
    job_name: "jupyter",
    job_owner: "johrstrom",
    dispatch_time: nil,
    submission_time: 1587580037,
    wallclock_time: nil,
    ood_connection_info: { host: "10.20.0.40" },
    procs: nil
  }}

  let(:single_unscheduleable_pod_hash) {{
    id: "bash",
    status: OodCore::Job::Status.new(state: "queued_held"),
    job_name: "bash",
    job_owner: "johrstrom",
    dispatch_time: nil,
    submission_time: 1587580582,
    wallclock_time: nil,
    ood_connection_info: { host: nil },
    procs: "1"
  }}

  let(:ns_prefixed_pod_hash) {{
    id: "jupyter-3o4n6z3e",
    status: OodCore::Job::Status.new(state: "running"),
    job_name: "jupyter",
    job_owner: "johrstrom",
    dispatch_time: 1607638123,
    submission_time: 1607637118,
    wallclock_time: 76885,
    ood_connection_info: { host: "192.148.247.227" },
    procs: "1"
  }}

  let(:pod_with_port) do
    pod = single_running_pod_hash
    pod[:ood_connection_info] = pod[:ood_connection_info].merge({ port: 30689 })
    pod
  end

  let(:pod_with_port_and_secret) do
    pod = pod_with_port
    pod[:ood_connection_info] = pod[:ood_connection_info].merge({ password: "ekmfxbOgNUlmLy4m" })
    pod
  end

  describe "#info_from_json" do
    it "correctly reads a running pods' info" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_running_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_running_pod_hash))
      expect(info.status.running?).to be true
    end

    it "correctly reads a running pods' info with service data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_running_pod,
        service_json: single_service,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(pod_with_port))
      expect(info.status.running?).to be true
    end

    it "correctly reads a running pods' info with service and secret data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_running_pod,
        service_json: single_service,
        secret_json: single_secret
      )

      expect(info).to eq(K8sJobInfo.new(pod_with_port_and_secret))
      expect(info.status.running?).to be true
    end

    it "correctly reads a errored pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_error_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_error_pod_hash))
      expect(info.status.suspended?).to be true
    end

    it "correctly reads a image errored pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_image_error_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_image_error_pod_hash))
      expect(info.status.queued?).to be true
    end

    it "correctly reads a crash loop pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_crash_loop_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_crash_loop_pod_hash))
      expect(info.status.undetermined?).to be true
    end

    it "correctly reads a completed pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_completed_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_completed_pod_hash))
      expect(info.status.completed?).to be true
    end

    it "correctly reads a queued pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_queued_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_queued_pod_hash))
      expect(info.status.queued?).to be true
    end


    it "correctly reads a unscheduleable pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.info_from_json(
        pod_json: single_unscheduleable_pod,
        service_json: nil,
        secret_json: nil
      )

      expect(info).to eq(K8sJobInfo.new(single_unscheduleable_pod_hash))
    end

    it "correctly throws exception on bad data" do
      empty_json = JSON.parse('{ }', symbolize_names: true)

      expect {
        helper.info_from_json(
          pod_json: empty_json,
          service_json: empty_json,
          secret_json: empty_json
        )
      }.to raise_error(Kubernetes::Helper::K8sDataError, "unable to read data correctly from json")
    end

    it "correctly deals with namespace prefixed pods" do
      allow(DateTime).to receive(:now).and_return(DateTime.parse("2020-12-11 14:30:08 -0500"))

      info = helper.info_from_json(
        pod_json: ns_prefixed_pod,
        service_json: nil,
        secret_json: nil,
        ns_prefix: 'user-'
      )

      expect(info).to eq(K8sJobInfo.new(ns_prefixed_pod_hash))
    end
  end

  describe "#container_from_native" do
    let(:ctr_hash) {
      {
        name: 'ruby-test-container',
        image: 'ruby:2.5',
        command: 'rake spec',
        port: 8080,
        env: {
          'HOME' => '/over/here',
        },
        memory: '12Gi',
        cpu: '6',
        working_dir: '/over/there',
        restart_policy: 'OnFailure',
        image_pull_secret: 'docker-registry-secret'
      }
    }

    let(:default_env) {
      {
        HOME: '/home/test',
        UID: 1000,
      }
    }

    it "correctly parses a full container" do
      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          port: 8080,
          command: ['rake', 'spec'],
          env: {
            HOME: '/over/here',
            UID: 1000,
          },
          memory: '12Gi',
          cpu: '6',
          working_dir: '/over/there',
          restart_policy: 'OnFailure',
          image_pull_secret: 'docker-registry-secret'
        )
      )
    end

    it "correctly parses container with no port" do
      ctr_hash.delete(:port)

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          command: ['rake', 'spec'],
          env: {
            HOME: '/over/here',
            UID: 1000,
          },
          memory: '12Gi',
          cpu: '6',
          working_dir: '/over/there',
          restart_policy: 'OnFailure',
          image_pull_secret: 'docker-registry-secret'
        )
      )
    end

    it "correctly parses container with no command" do
      ctr_hash.delete(:command)

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          port: 8080,
          env: {
            HOME: '/over/here',
            UID: 1000,
          },
          memory: '12Gi',
          cpu: '6',
          working_dir: '/over/there',
          restart_policy: 'OnFailure',
          image_pull_secret: 'docker-registry-secret'
        )
      )
    end

    it "correctly parses container with no env" do
      ctr_hash.delete(:env)

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          port: 8080,
          env: {
            HOME: '/home/test',
            UID: 1000,
          },
          command: ['rake', 'spec'],
          memory: '12Gi',
          cpu: '6',
          working_dir: '/over/there',
          restart_policy: 'OnFailure',
          image_pull_secret: 'docker-registry-secret'
        )
      )
    end

    it "correctly parses container with working directory" do
      ctr_hash.delete(:working_dir)

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          port: 8080,
          env: {
            HOME: '/over/here',
            UID: 1000,
          },
          command: ['rake', 'spec'],
          memory: '12Gi',
          cpu: '6',
          restart_policy: 'OnFailure',
          image_pull_secret: 'docker-registry-secret'
        )
      )
    end

    it "correctly parses container with no restart_policy" do
      ctr_hash.delete(:restart_policy)

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          port: 8080,
          command: ['rake', 'spec'],
          env: {
            HOME: '/over/here',
            UID: 1000,
          },
          memory: '12Gi',
          cpu: '6',
          working_dir: '/over/there',
          restart_policy: 'Never',
          image_pull_secret: 'docker-registry-secret'
        )
      )
    end

    it "correctly parses container with no image_pull_secret" do
      ctr_hash.delete(:image_pull_secret)

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          port: 8080,
          command: ['rake', 'spec'],
          env: {
            HOME: '/over/here',
            UID: 1000,
          },
          memory: '12Gi',
          cpu: '6',
          working_dir: '/over/there',
          restart_policy: 'OnFailure',
          image_pull_secret: nil
        )
      )
    end

    it "correctly parses container with no extra fields" do
      # expected defaults
      ctr_hash[:env] = {}
      ctr_hash[:command] = []
      ctr_hash.delete(:port)
      ctr_hash[:memory] = '4Gi'
      ctr_hash[:cpu] = '1'
      ctr_hash[:restart_policy] = 'Never'
      ctr_hash[:working_dir] = ''
      ctr_hash[:image_pull_secret] = nil

      expect(helper.container_from_native(ctr_hash, default_env)).to eq(
        Kubernetes::Resources::Container.new(
          'ruby-test-container',
          'ruby:2.5',
          env: {
            HOME: '/home/test',
            UID: 1000,
          }
        )
      )
    end

    it "throws an error when no name is given" do
      ctr = { image: 'ruby:25' }
      expect{ 
        helper.container_from_native(ctr, default_env)
      }.to raise_error(ArgumentError, "containers need valid names and images")
    end

    it "throws an error when no name is given" do
      ctr = { name: 'ruby-test-container' }
      expect{ 
        helper.container_from_native(ctr, default_env)
      }.to raise_error(ArgumentError, "containers need valid names and images")
    end
  end

  describe "#parse_command" do
    it "correctly parses a string" do
      cmd = "ls -lrt /foo/bar"

      cmd_arr = helper.parse_command(cmd)
      expect(cmd_arr).to eql(['ls', '-lrt', '/foo/bar'])
    end

    it "correctly parses an quoted arguments" do
      cmd = "ls -lrt /foo/bar '/dir/with/a space'"

      cmd_arr = helper.parse_command(cmd)
      expect(cmd_arr).to eql(['ls', '-lrt', '/foo/bar', '/dir/with/a space'])
    end

    it "returns an array if given an array" do
      arr = ['ls', '-lrt', '/foo/bar']
      expect(helper.parse_command(arr)).to eql(arr)
    end

    it "accepts nil" do
      expect(helper.parse_command(nil)).to eql([])
    end
  end

  describe "#seconds_to_duration" do
    it "handles seconds to duration" do
      expect(helper.seconds_to_duration(3600)).to eq('01h00m00s')
      expect(helper.seconds_to_duration(3660)).to eq('01h01m00s')
      expect(helper.seconds_to_duration(3662)).to eq('01h01m02s')
    end
  end

  describe "#pod_info_from_json" do
    it "correctly reads a running pods' info" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.pod_info_from_json(single_running_pod)

      expect(info).to eq(single_running_pod_hash)
    end

    it "correctly reads a errored pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.pod_info_from_json(single_error_pod)

      expect(info).to eq(single_error_pod_hash)
    end

    it "correctly reads a completed pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.pod_info_from_json(single_completed_pod)

      expect(info).to eq(single_completed_pod_hash)
    end

    it "correctly reads a queued pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.pod_info_from_json(single_queued_pod)

      expect(info).to eq(single_queued_pod_hash)
    end

    it "correctly reads a unscheduleable pods' data" do
      allow(DateTime).to receive(:now).and_return(now)

      info = helper.pod_info_from_json(single_unscheduleable_pod)

      expect(info).to eq(single_unscheduleable_pod_hash)
    end

    it "correctly throws exception on bad data" do
      empty_json = JSON.parse('{ }', symbolize_names: true)

      expect {
        helper.pod_info_from_json(empty_json)
      }.to raise_error(Kubernetes::Helper::K8sDataError, "unable to read data correctly from json")
    end

    it "correctly deals with namespace prefixed pods" do
      allow(DateTime).to receive(:now).and_return(DateTime.parse("2020-12-11 14:30:08 -0500"))

      info = helper.pod_info_from_json(ns_prefixed_pod, ns_prefix: 'user-')

      expect(info).to eq(ns_prefixed_pod_hash)
    end
  end
end