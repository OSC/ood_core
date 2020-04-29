require "ood_core/job/adapters/kubernetes"
require "ood_core/job/adapters/kubernetes/batch"

describe OodCore::Job::Adapters::Kubernetes::Batch do

  Batch = OodCore::Job::Adapters::Kubernetes::Batch

  let(:helper) { double }
  let(:create_pod_yml) { File.read('spec/fixtures/output/k8s/expected_pod_create.yml') }
  let(:several_pods) { File.read('spec/fixtures/output/k8s/several_pods.json') }
  let(:single_running_pod) { File.read('spec/fixtures/output/k8s/single_running_pod.json') }
  let(:single_error_pod) { File.read('spec/fixtures/output/k8s/single_error_pod.json') }
  let(:single_completed_pod) { File.read('spec/fixtures/output/k8s/single_completed_pod.json') }
  let(:single_queued_pod) { File.read('spec/fixtures/output/k8s/single_queued_pod.json') }
  let(:single_pending_pod) { File.read('spec/fixtures/output/k8s/single_pending_pod.json') }
  let(:single_service) { File.read('spec/fixtures/output/k8s/single_service.json') }
  let(:single_secret) { File.read('spec/fixtures/output/k8s/single_secret.json') }

  let(:now) { DateTime.parse("2020-04-28 20:18:30 +0000") }
  let(:past) { DateTime.parse("2020-04-18 13:01:56 +0000") }

  let(:mounts) {
    [
      {
        type: 'host',
        name: 'home-dir',
        host_type: 'Directory',
        destination_path: '/home',
        path: '/users'
      },
      {
        type: 'nfs',
        name: 'nfs-dir',
        host: 'some.nfs.host',
        destination_path: '/fs',
        path: '/fs'
      }
    ]
  }

  let(:config) {
    {
      config_file: '~/kube.config',
      bin: '/usr/bin/wontwork',
      restart_policy: 'Always',
      cluster_name: 'test-cluster',
      mounts: mounts,
      all_namespaces: true,
      server: {
        endpoint: 'https://some.k8s.host',
        cert_authority_file: '/etc/some.cert'
      }
    }
  }

  before(:each) do
    `true`
    allow(Open3).to receive(:capture3).with(
      {},
      "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
      "config set-cluster open-ondemand --server=https://localhost:8080",
      stdin_data: ""
    ).and_return(['', '', $?])

    @basic_batch = described_class.new
    allow(@basic_batch).to receive(:username).and_return('testuser')
  end

  let(:configured_batch){
    `true`
    allow(Open3).to receive(:capture3).with(
      {},
      "/usr/bin/wontwork --kubeconfig=~/kube.config " \
      "config set-cluster test-cluster --server=https://some.k8s.host " \
      "--certificate-authority=/etc/some.cert",
      stdin_data: ""
    ).and_return(['', '', $?])

    batch = described_class.new(config)
    allow(batch).to receive(:username).and_return('testuser')

    batch
  }

  let(:several_pods_info){
    [
      OodCore::Job::Info.new({
        id: "bash",
        status:  "completed",
        job_name: "bash",
        job_owner: "johrstrom",
        dispatch_time: 1588023136,
        submission_time: 1588023135,
        wallclock_time: 300,
        native: {
          host: "10.20.0.40"
        }
      }),
      OodCore::Job::Info.new({
        id: "bash-ssd",
        status:  "undetermined",
        job_name: "bash-ssd",
        job_owner: "johrstrom",
        dispatch_time: nil,
        submission_time: 1588023155,
        wallclock_time: nil,
        native: {
          host: nil
        }
      }),
      OodCore::Job::Info.new({
        id: 'jupyter-3pjruck9',
        status: 'suspended',
        job_name: "jupyter",
        job_owner: "johrstrom",
        dispatch_time: nil,
        submission_time: 1588106996,
        wallclock_time: nil,
        native: {
          host: "10.20.0.40"
        }
      }),
      OodCore::Job::Info.new({
        id: 'jupyter-q323v88u',
        status: 'running',
        job_name: "jupyter",
        job_owner: "johrstrom",
        dispatch_time: 1588089059,
        submission_time: 1588089047,
        wallclock_time: 16051,
        native: {
          host: "10.20.0.40"
        }
      })
    ]
  }

  let(:single_running_pod_info) {
    OodCore::Job::Info.new({
      id: "jupyter-bmurb8sa",
      status: OodCore::Job::Status.new(state: "running"),
      job_name: "jupyter",
      job_owner: "johrstrom",
      dispatch_time: 1587060509,
      submission_time: 1587060496,
      wallclock_time: 154407,
      native: {
        host: "10.20.0.40"
      }
    })
  }

  let(:single_running_pod_with_native_info) {
    OodCore::Job::Info.new({
      id: "jupyter-bmurb8sa",
      status: OodCore::Job::Status.new(state: "running"),
      job_name: "jupyter",
      job_owner: "johrstrom",
      dispatch_time: 1587060509,
      submission_time: 1587060496,
      wallclock_time: 154407,
      native: {
        host: "10.20.0.40",
        port: 30689,
        password:  "ekmfxbOgNUlmLy4m"
      }
    })
  }

  let(:single_error_pod_info) {
    OodCore::Job::Info.new({
      id: "jupyter-h6kw06ve",
      status: OodCore::Job::Status.new(state: "suspended"),
      job_name: "jupyter",
      job_owner: "johrstrom",
      dispatch_time: nil,
      submission_time: 1587069112,
      wallclock_time: nil,
      native: {
        host: "10.20.0.40"
      }
    })
  }

  let(:single_completed_pod_info) {
    OodCore::Job::Info.new({
      id: "bash",
      status: OodCore::Job::Status.new(state: "completed"),
      job_name: "bash",
      job_owner: "johrstrom",
      dispatch_time: 1587506633,
      submission_time: 1587506632,
      wallclock_time: 300,
      native: {
        host: "10.20.0.40"
      }
    })
  }


  let(:single_queued_pod_info) {
    OodCore::Job::Info.new({
      id: "jupyter-28wixphq",
      status: OodCore::Job::Status.new(state: "queued"),
      job_name: "jupyter",
      job_owner: "johrstrom",
      dispatch_time: nil,
      submission_time: 1587580037,
      wallclock_time: nil,
      native: {
        host: "10.20.0.40"
      }
    })
  }

  let(:single_pending_pod_info) {
    OodCore::Job::Info.new({
      id: "bash",
      status: OodCore::Job::Status.new(state: "undetermined"),
      job_name: "bash",
      job_owner: "johrstrom",
      dispatch_time: nil,
      submission_time: 1587580581,
      wallclock_time: nil,
      native: {
        host: nil
      }
    })
  }


  describe "#initialize" do
    it "configures correctly when given items" do
      expect(configured_batch.config_file).to eq('~/kube.config')
      expect(configured_batch.bin).to eq('/usr/bin/wontwork')
      expect(configured_batch.restart_policy).to eq('Always')
      expect(configured_batch.mounts).to eq(mounts)
    end

    it "configures correctly configures defaults" do
      expect(@basic_batch.config_file).to eq("#{ENV['HOME']}/.kube/config")
      expect(@basic_batch.bin).to eq('/usr/bin/kubectl')
      expect(@basic_batch.restart_policy).to eq('Never')
      expect(@basic_batch.mounts).to eq([])
    end

    it "does not throw an error when it can't configure" do
      `false` # false here means call() should throw errors
      allow(Open3).to receive(:capture3).and_return(['', '', $?])

      expect { described_class.new }.not_to raise_error
      expect { described_class.new(config) }.not_to raise_error
    end
  end

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        {
          content: nil
        }.merge opts
      )
    end

    it "submits with correct yml file" do
      script = build_script(
        native: {
          container: {
            name: 'rspec-test',
            image: 'ruby:2.5',
            command: 'rake spec',
            port: 8080,
            env: [
              {
                name: 'HOME',
                value: '/my/home'
              },
              {
                name: 'PATH',
                value: '/usr/bin:/usr/local/bin'
              }
            ]
          },
          init_containers: [
            name: 'init-1',
            image: 'busybox:latest',
            command: '/bin/ls -lrt .'
          ],
          configmap: {
            filename: 'config.file',
            data: 'a = b'
          }
        }
      )

      allow(configured_batch).to receive(:generate_id).with('rspec-test').and_return('rspec-test-123')
      allow(configured_batch).to receive(:username).and_return('testuser')
      allow(configured_batch).to receive(:run_as_user).and_return(1001)
      allow(configured_batch).to receive(:run_as_group).and_return(1002)

      # make sure it get's templated right, also helpful in debugging bc
      # it'll show a better diff than the test below.
      template, = configured_batch.send(:generate_id_yml, script.native)
      expect(template.to_s).to eql(create_pod_yml.to_s)

      # make sure template get's passed into command correctly
      `true`
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/wontwork --kubeconfig=~/kube.config " \
        "--namespace=testuser -o json create -f -",
        stdin_data: create_pod_yml
      ).and_return(['', '', $?])

      configured_batch.submit(script)
    end
  end

  describe "#delete" do
    it "deletes all the resources with the right commands" do

      # be sure to delete the pod and all the extra resources
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete pod test-pod-123",
        stdin_data: ""
      ).and_return(['', '', $?])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete secret test-pod-123-secret",
        stdin_data: ""
      ).and_return(['', '', $?])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete service test-pod-123-service",
        stdin_data: ""
      ).and_return(['', '', $?])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete configmap test-pod-123-configmap",
        stdin_data: ""
      ).and_return(['', '', $?])

      @basic_batch.delete('test-pod-123')
    end
  end

  describe "#info_all" do
    it "correctly handles no data" do
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser get pods -o json",
        stdin_data: ""
      ).and_return(['No resources found in testuser namespace.', '', $?])

      expect(@basic_batch.info_all).to eq([])
    end

    it "throws error up the stack with --all-namespaces" do
      `false`
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/wontwork --kubeconfig=~/kube.config get pods -o json --all-namespaces",
        stdin_data: ""
      ).and_return(['', 'Error from server (Forbidden): pods is forbidden: User "testuser" cannot list resource "pods" in API group "" at the cluster scope', $?])

      expect { configured_batch.info_all }.to raise_error(Batch::Error)
    end

    it "correctly handles good data" do
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser get pods -o json",
        stdin_data: ""
      ).and_return([several_pods, '', $?])

      allow(DateTime).to receive(:now).and_return(now)

      expect(@basic_batch.info_all).to eq(several_pods_info)
    end
  end

  describe "#info" do
    def info_batch(id, file)
      `true`
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "config set-cluster open-ondemand --server=https://localhost:8080",
        stdin_data: ""
      ).and_return(['', '', $?])

      batch = described_class.new
      allow(batch).to receive(:username).and_return('testuser')
      allow(DateTime).to receive(:now).and_return(past)

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get pod #{id}",
        stdin_data: ""
      ).and_return([file, '', $?])

      `false`
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get service #{id}-service",
        stdin_data: ""
      ).and_return(['', 'error message', $?])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get secret #{id}-secret",
        stdin_data: ""
      ).and_return(['', 'error message', $?])

      batch
    end

    def info_batch_full(id)
      `true`
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "config set-cluster open-ondemand --server=https://localhost:8080",
        stdin_data: ""
      ).and_return(['', '', $?])

      batch = described_class.new
      allow(batch).to receive(:username).and_return('testuser')
      allow(DateTime).to receive(:now).and_return(past)

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get pod #{id}",
        stdin_data: ""
      ).and_return([single_running_pod, '', $?])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get service #{id}-service",
        stdin_data: ""
      ).and_return([single_service, '', $?])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get secret #{id}-secret",
        stdin_data: ""
      ).and_return([single_secret, '', $?])

      batch
    end

    it "correctly returns a running pod" do
      batch = info_batch('jupyter-bmurb8sa', single_running_pod)
      expect(batch.info('jupyter-bmurb8sa')).to eq(single_running_pod_info)
    end

    it "correctly returns a errored pod" do
      batch = info_batch('jupyter-h6kw06ve', single_error_pod)
      expect(batch.info('jupyter-h6kw06ve')).to eq(single_error_pod_info)
    end

    it "correctly returns a completed pod" do
      batch = info_batch('bash', single_completed_pod)
      expect(batch.info('bash')).to eq(single_completed_pod_info)
    end

    it "correctly returns a queued pod" do
      batch = info_batch('jupyter-28wixphq', single_queued_pod)
      expect(batch.info('jupyter-28wixphq')).to eq(single_queued_pod_info)
    end

    it "correctly returns a pending pod" do
      batch = info_batch('bash', single_pending_pod)
      expect(batch.info('bash')).to eq(single_pending_pod_info)
    end

    it "correctly returns native info from service and secret" do
      batch = info_batch_full("jupyter-bmurb8sa")
      expect(batch.info("jupyter-bmurb8sa")).to eq(single_running_pod_with_native_info)
    end
  end

end
