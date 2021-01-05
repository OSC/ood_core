require "ood_core/job/adapters/kubernetes"
require "ood_core/job/adapters/kubernetes/batch"

describe OodCore::Job::Adapters::Kubernetes::Batch do

  Batch = OodCore::Job::Adapters::Kubernetes::Batch
  Helper = OodCore::Job::Adapters::Kubernetes::Helper

  let(:helper) {
    helper = Helper.new
    allow(helper).to receive(:get_host).with(nil).and_return(nil)
    allow(helper).to receive(:get_host).with('10.20.0.40').and_return('10.20.0.40')
    allow(helper).to receive(:get_host).with('192.148.247.227').and_return('192.148.247.227')
    helper
  }

  let(:pod_yml_from_all_configs) { File.read('spec/fixtures/output/k8s/pod_yml_from_all_configs.yml') }
  let(:pod_yml_from_defaults) { File.read('spec/fixtures/output/k8s/pod_yml_from_defaults.yml') }
  let(:pod_yml_no_mounts) { File.read('spec/fixtures/output/k8s/pod_yml_no_mounts.yml') }
  let(:several_pods) { File.read('spec/fixtures/output/k8s/several_pods.json') }
  let(:single_running_pod) { File.read('spec/fixtures/output/k8s/single_running_pod.json') }
  let(:single_error_pod) { File.read('spec/fixtures/output/k8s/single_error_pod.json') }
  let(:single_completed_pod) { File.read('spec/fixtures/output/k8s/single_completed_pod.json') }
  let(:single_queued_pod) { File.read('spec/fixtures/output/k8s/single_queued_pod.json') }
  let(:single_unscheduleable_pod) { File.read('spec/fixtures/output/k8s/single_unscheduleable_pod.json') }
  let(:single_service) { File.read('spec/fixtures/output/k8s/single_service.json') }
  let(:single_secret) { File.read('spec/fixtures/output/k8s/single_secret.json') }
  let(:single_secret) { File.read('spec/fixtures/output/k8s/single_secret.json') }
  let(:ns_prefixed_pod) { File.read('spec/fixtures/output/k8s/ns_prefixed_pod.json') }

  let(:now) { DateTime.parse("2020-04-28 20:18:30 +0000") }
  let(:past) { DateTime.parse("2020-04-18 13:01:56 +0000") }

  let(:success) { double("success?" => true) }
  let(:failure) { double("success?" => false) }

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
      cluster: 'test-cluster',
      mounts: mounts,
      all_namespaces: true,
      namespace_prefix: 'user-',
      username_prefix: 'dev',
      server: {
        endpoint: 'https://some.k8s.host',
        cert_authority_file: '/etc/some.cert'
      }
    }
  }

  before(:each) do
    allow(Open3).to receive(:capture3).with(
      {},
      "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
      "config set-cluster open-ondemand --server=https://localhost:8080",
      stdin_data: ""
    ).and_return(['', '', success])

    @basic_batch = described_class.new({})
    allow(@basic_batch).to receive(:username).and_return('testuser')
    allow(@basic_batch).to receive(:helper).and_return(helper)
  end

  let(:configured_batch){
    allow(Open3).to receive(:capture3).with(
      {},
      "/usr/bin/wontwork --kubeconfig=~/kube.config " \
      "config set-cluster test-cluster --server=https://some.k8s.host " \
      "--certificate-authority=/etc/some.cert",
      stdin_data: ""
    ).and_return(['', '', success])

    batch = described_class.new(config)
    allow(batch).to receive(:username).and_return('testuser')
    allow(batch).to receive(:helper).and_return(helper)

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
        status:  "queued",
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
      },
      procs: 1
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
      },
      procs: 1
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

  let(:single_unscheduleable_pod_info) {
    OodCore::Job::Info.new({
      id: "bash",
      status: OodCore::Job::Status.new(state: "queued"),
      job_name: "bash",
      job_owner: "johrstrom",
      dispatch_time: nil,
      submission_time: 1587580581,
      wallclock_time: nil,
      native: {
        host: nil
      },
      procs: 1
    })
  }


  describe "#initialize" do
    it "configures correctly when given items" do
      expect(configured_batch.config_file).to eq('~/kube.config')
      expect(configured_batch.bin).to eq('/usr/bin/wontwork')
      expect(configured_batch.mounts).to eq(mounts)
      expect(configured_batch.namespace_prefix).to eq('user-')
    end

    it "configures correctly configures defaults" do
      expect(@basic_batch.config_file).to eq("#{ENV['HOME']}/.kube/config")
      expect(@basic_batch.bin).to eq('/usr/bin/kubectl')
      expect(@basic_batch.mounts).to eq([])
    end

    it "does not throw an error when it can't configure" do
      allow(Open3).to receive(:capture3).and_return(['', '', failure])

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

    it "submits with correct yml file given all config options" do
      script = build_script(
        accounting_id: 'test',
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
            ],
            memory: '6Gi',
            cpu: '4',
            working_dir: '/my/home',
            restart_policy: 'Always'
          },
          init_containers: [
            name: 'init-1',
            image: 'busybox:latest',
            command: '/bin/ls -lrt .'
          ],
          configmap: {
            filename: 'config.file',
            data: "a = b\nc = d\n  indentation = keepthis"
          },
          mounts: [
            type: 'host',
            name: 'ess',
            host_type: 'Directory',
            destination_path: '/fs/ess',
            path: '/fs/ess'
          ]
        }
      )

      allow(configured_batch).to receive(:generate_id).with('rspec-test').and_return('rspec-test-123')
      allow(configured_batch).to receive(:username).and_return('testuser')
      allow(configured_batch).to receive(:run_as_user).and_return(1001)
      allow(configured_batch).to receive(:run_as_group).and_return(1002)

      # make sure it get's templated right, also helpful in debugging bc
      # it'll show a better diff than the test below.
      template, = configured_batch.send(:generate_id_yml, script)
      expect(template.to_s).to eql(pod_yml_from_all_configs.to_s)

      # make sure template get's passed into command correctly
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/wontwork --kubeconfig=~/kube.config " \
        "--namespace=user-testuser -o json create -f -",
        stdin_data: pod_yml_from_all_configs.to_s
      ).and_return(['', '', success])

      configured_batch.submit(script)
    end

    it "submits with correct yml file given default options" do
      script = build_script(
        accounting_id: 'test',
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
            ],
            memory: '6Gi',
            cpu: '4',
            working_dir: '/my/home',
            restart_policy: 'Always'
          },
          init_containers: [
            name: 'init-1',
            image: 'busybox:latest',
            command: '/bin/ls -lrt .'
          ],
          configmap: {
            filename: 'config.file',
            data: "a = b\nc = d\n  indentation = keepthis"
          },
          mounts: [
            type: 'host',
            name: 'ess',
            host_type: 'Directory',
            destination_path: '/fs/ess',
            path: '/fs/ess'
          ]
        }
      )

      allow(@basic_batch).to receive(:generate_id).with('rspec-test').and_return('rspec-test-123')
      allow(@basic_batch).to receive(:username).and_return('testuser')
      allow(@basic_batch).to receive(:run_as_user).and_return(1001)
      allow(@basic_batch).to receive(:run_as_group).and_return(1002)

      # make sure it get's templated right, also helpful in debugging bc
      # it'll show a better diff than the test below.
      template, = @basic_batch.send(:generate_id_yml, script)
      expect(template.to_s).to eql(pod_yml_from_defaults.to_s)

      # make sure template get's passed into command correctly
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json create -f -",
        stdin_data: pod_yml_from_defaults.to_s
      ).and_return(['', '', success])

      @basic_batch.submit(script)
    end

    it "submits with correct yml file with no mounts" do
      script = build_script(
        accounting_id: 'test',
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
            ],
            memory: '6Gi',
            cpu: '4',
            working_dir: '/my/home',
            restart_policy: 'Always'
          },
          init_containers: [
            name: 'init-1',
            image: 'busybox:latest',
            command: '/bin/ls -lrt .'
          ],
          configmap: {
            filename: 'config.file',
            data: "a = b\nc = d\n  indentation = keepthis"
          },
        }
      )

      allow(@basic_batch).to receive(:generate_id).with('rspec-test').and_return('rspec-test-123')
      allow(@basic_batch).to receive(:username).and_return('testuser')
      allow(@basic_batch).to receive(:run_as_user).and_return(1001)
      allow(@basic_batch).to receive(:run_as_group).and_return(1002)

      # make sure it get's templated right, also helpful in debugging bc
      # it'll show a better diff than the test below.
      template, = @basic_batch.send(:generate_id_yml, script)
      expect(template.to_s).to eql(pod_yml_no_mounts.to_s)

      # make sure template get's passed into command correctly
      `true`
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json create -f -",
        stdin_data: pod_yml_no_mounts.to_s
      ).and_return(['', '', $?])

      @basic_batch.submit(script)
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
      ).and_return(['', '', success])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete secret test-pod-123-secret",
        stdin_data: ""
      ).and_return(['', '', success])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete service test-pod-123-service",
        stdin_data: ""
      ).and_return(['', '', success])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete configmap test-pod-123-configmap",
        stdin_data: ""
      ).and_return(['', '', success])

      @basic_batch.delete('test-pod-123')
    end

    it "safely tries to delete resources that don't exist" do

      id = "rspec-test"

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete pod #{id}",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): pods \"#{id}\" not found", failure])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete secret #{id}-secret",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): secrets \"#{id}-secret\" not found", failure])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete service #{id}-service",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): services \"#{id}-service\" not found", failure])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser delete configmap #{id}-configmap",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): configmaps \"#{id}-configmap\" not found", failure])

      @basic_batch.delete(id)
    end
  end

  describe "#info_all" do
    it "correctly handles no data" do
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser get pods -o json",
        stdin_data: ""
      ).and_return(['No resources found in testuser namespace.', '', success])

      expect(@basic_batch.info_all).to eq([])
    end

    errmsg = 'Error from server (Forbidden): pods is forbidden: User "testuser" cannot list resource "pods" in API group "" at the cluster scope'
    it "throws error up the stack with --all-namespaces" do
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/wontwork --kubeconfig=~/kube.config get pods -o json --all-namespaces",
        stdin_data: ""
      ).and_return(['', errmsg, failure])

      expect { configured_batch.info_all }.to raise_error(Batch::Error, errmsg)
    end

    it "correctly handles good data" do
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser get pods -o json",
        stdin_data: ""
      ).and_return([several_pods, '', success])

      allow(DateTime).to receive(:now).and_return(now)

      expect(@basic_batch.info_all).to eq(several_pods_info)
    end
  end

  describe "#info" do
    def info_batch(id, file)
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "config set-cluster open-ondemand --server=https://localhost:8080",
        stdin_data: ""
      ).and_return(['', '', success])

      batch = described_class.new({})
      allow(batch).to receive(:username).and_return('testuser')
      allow(batch).to receive(:helper).and_return(helper)
      allow(DateTime).to receive(:now).and_return(past)

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get pod #{id}",
        stdin_data: ""
      ).and_return([file, '', success])

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get service #{id}-service",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): services \"#{id}-service\" not found", failure])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get secret #{id}-secret",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): secret \"#{id}-secret\" not found", failure])

      batch
    end

    def info_batch_full(id)
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "config set-cluster open-ondemand --server=https://localhost:8080",
        stdin_data: ""
      ).and_return(['', '', success])

      batch = described_class.new({})
      allow(batch).to receive(:username).and_return('testuser')
      allow(DateTime).to receive(:now).and_return(past)

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get pod #{id}",
        stdin_data: ""
      ).and_return([single_running_pod, '', success])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get service #{id}-service",
        stdin_data: ""
      ).and_return([single_service, '', success])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get secret #{id}-secret",
        stdin_data: ""
      ).and_return([single_secret, '', success])

      batch
    end

    def not_found_batch(id)
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "config set-cluster open-ondemand --server=https://localhost:8080",
        stdin_data: ""
      ).and_return(['', '', success])

      batch = described_class.new({})
      allow(batch).to receive(:username).and_return('testuser')
      allow(batch).to receive(:helper).and_return(helper)
      allow(DateTime).to receive(:now).and_return(past)

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get pod #{id}",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): pod \"#{id}\" not found", failure])

      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get service #{id}-service",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): services \"#{id}-service\" not found", failure])
      allow(Open3).to receive(:capture3).with(
        {},
        "/usr/bin/kubectl --kubeconfig=#{ENV['HOME']}/.kube/config " \
        "--namespace=testuser -o json get secret #{id}-secret",
        stdin_data: ""
      ).and_return(['', "Error from server (NotFound): secret \"#{id}-secret\" not found", failure])

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

    it "correctly returns a unscheduleable pod" do
      batch = info_batch('bash', single_unscheduleable_pod)
      expect(batch.info('bash')).to eq(single_unscheduleable_pod_info)
    end

    it "correctly returns native info from service and secret" do
      batch = info_batch_full("jupyter-bmurb8sa")
      expect(batch.info("jupyter-bmurb8sa")).to eq(single_running_pod_with_native_info)
    end

    it "handles not finding the pod" do
      id = "jupyter-3o4n6z3e"
      batch = not_found_batch(id)
      completed_info = OodCore::Job::Info.new({ id: id, status: 'completed' })
      expect(batch.info(id)).to eq(completed_info)
    end
  end

end
