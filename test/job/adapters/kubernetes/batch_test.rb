require 'test_helper'
require 'ood_core/job/adapters/kubernetes'
require 'ood_core/job/adapters/kubernetes/batch'
require 'tmpdir'

class TestKubernetesBatch < Minitest::Test
  include TestHelper

  Batch = OodCore::Job::Adapters::Kubernetes::Batch
  K8sJobInfo = OodCore::Job::Adapters::Kubernetes::K8sJobInfo
  User = Struct.new(:dir, :uid, :gid, keyword_init: true)

  FIXTURES = 'spec/fixtures/output/k8s'

  def setup
    # The default config file honors KUBECONFIG, so make sure the
    # environment running the tests doesn't leak into them.
    @kubeconfig = ENV.delete('KUBECONFIG')

    # get_host does a reverse DNS lookup; fail it so the IP is used as-is.
    Resolv.stubs(:getname).raises(Resolv::ResolvError)
  end

  def teardown
    ENV['KUBECONFIG'] = @kubeconfig unless @kubeconfig.nil?
  end

  def fixture(name)
    File.read("#{FIXTURES}/#{name}")
  end

  def mounts
    [
      { type: 'host', name: 'home-dir', host_type: 'Directory', destination_path: '/home', path: '/users' },
      { type: 'nfs', name: 'nfs-dir', host: 'some.nfs.host', destination_path: '/fs', path: '/fs' }
    ]
  end

  def config
    {
      config_file: '~/kube.config',
      bin: '/usr/bin/wontwork',
      cluster: 'test-cluster',
      context: 'ood-test-cluster',
      mounts: mounts,
      all_namespaces: true,
      namespace_prefix: 'user-',
      username_prefix: 'dev-',
      server: {
        endpoint: 'https://some.k8s.host',
        cert_authority_file: '/etc/some.cert'
      },
      auth: {
        type: 'oidc'
      },
      auto_supplemental_groups: true
    }
  end

  def basic_batch
    batch = Batch.new({})
    batch.stubs(:username).returns('testuser')
    batch
  end

  def configured_batch
    batch = Batch.new(config)
    batch.stubs(:username).returns('testuser')
    batch
  end

  # kubectl command line for a default-configured batch in the testuser namespace
  def kubectl(args)
    "/usr/bin/kubectl --kubeconfig=#{Dir.home}/.kube/config --namespace=testuser #{args}"
  end

  def stub_kubectl(cmd, stdout: '', stderr: '', success: true, stdin: '')
    Open3.stubs(:capture3)
         .with({}, cmd, stdin_data: stdin)
         .returns([stdout, stderr, success ? exit_success : exit_failure])
  end

  def expect_kubectl(cmd, stdout: '', stderr: '', success: true, stdin: '')
    Open3.expects(:capture3)
         .with({}, cmd, stdin_data: stdin)
         .returns([stdout, stderr, success ? exit_success : exit_failure])
  end

  def not_found(resource, name)
    "Error from server (NotFound): #{resource} \"#{name}\" not found"
  end

  def freeze_now(time)
    DateTime.stubs(:now).returns(DateTime.parse(time))
  end

  # ---- initialize ----

  def test_configures_given_options
    batch = configured_batch

    assert_equal('~/kube.config', batch.config_file)
    assert_equal('/usr/bin/wontwork', batch.bin)
    assert_equal(mounts, batch.mounts)
    assert_equal('user-', batch.namespace_prefix)
  end

  def test_configures_defaults
    batch = basic_batch

    assert_equal("#{Dir.home}/.kube/config", batch.config_file)
    assert_equal('/usr/bin/kubectl', batch.bin)
    assert_equal([], batch.mounts)
    assert_nil(batch.context)
  end

  def test_default_config_file_honors_kubeconfig
    ENV['KUBECONFIG'] = '/etc/kube/ood.config'

    assert_equal('/etc/kube/ood.config', Batch.new({}).config_file)
  ensure
    ENV.delete('KUBECONFIG')
  end

  def test_initialize_does_not_call_kubectl
    Open3.expects(:capture3).never

    Batch.new
    Batch.new(config)
    Batch.new({})
  end

  def test_context_defaults_to_cluster_for_oidc_auth
    batch = Batch.new({ 'cluster' => 'some-cluster', 'auth' => { 'type' => 'oidc' } })

    assert_equal('some-cluster', batch.cluster)
    assert_equal('some-cluster', batch.context)
    assert(batch.send(:context?))
  end

  # ---- submit ----

  def submit_script(native, **extra)
    OodCore::Job::Script.new(
      accounting_id: 'test',
      content: "#!/bin/bash\nfoo",
      native: native,
      **extra
    )
  end

  def stub_identity(batch)
    batch.stubs(:generate_id).with('rspec-test').returns('rspec-test-123')
    batch.stubs(:user).returns(User.new(dir: '/home/testuser', uid: 1001, gid: 1002))
    batch.stubs(:group).returns('testgroup')
  end

  def container(**overrides)
    {
      name: 'rspec-test',
      image: 'ruby:2.5',
      command: 'rake spec',
      port: 8080,
      env: {
        'HOME' => '/my/home',
        'PATH' => '/usr/bin:/usr/local/bin'
      },
      memory: '6Gi',
      cpu: '4',
      working_dir: '/my/home',
      restart_policy: 'Always'
    }.merge(overrides)
  end

  def init_containers
    [{ name: 'init-1', image: 'busybox:latest', command: '/bin/ls -lrt .' }]
  end

  def config_file
    { filename: 'config.file', data: "a = b\nc = d\n  indentation = keepthis", mount_path: '/ood' }
  end

  def ess_mount
    [{ type: 'host', name: 'ess', host_type: 'Directory', destination_path: '/fs/ess', path: '/fs/ess' }]
  end

  # Renders the pod yml, checks it against the recorded fixture, then submits
  # and checks the same yml is what kubectl receives on stdin.
  def assert_submits(batch, script, fixture_name, cmd)
    expected_yml = fixture(fixture_name)

    template, = batch.send(:generate_id_yml, script)
    assert_equal(expected_yml, template.to_s)

    expect_kubectl(cmd, stdin: expected_yml)
    assert_equal('rspec-test-123', batch.submit(script))
  end

  def test_submit_with_all_config_options
    batch = configured_batch
    stub_identity(batch)
    batch.stubs(:default_supplemental_groups).returns([1000, 1001])

    script = submit_script({
      container: {
        name: 'rspec-test',
        image: 'ruby:2.5',
        image_pull_secret: 'docker-registry-secret',
        image_pull_policy: 'Always',
        command: 'rake spec',
        port: 8080,
        startup_probe: { failure_threshold: 10 },
        env: {
          HOME: '/my/home',
          PATH: '/usr/bin:/usr/local/bin',
          KUBECONFIG: '/my/home/.kube/config'
        },
        labels: { cluster: 'foo' },
        memory_limit: '4Gi',
        memory_request: '2Gi',
        cpu_limit: '1',
        cpu_request: '0.5',
        working_dir: '/my/home',
        restart_policy: 'Always'
      },
      init_containers: [{ name: 'init-1', image: 'busybox:latest', image_pull_policy: 'Always', command: '/bin/ls -lrt .' }],
      configmap: { files: [config_file.merge(init_mount_path: '/ood')] },
      mounts: ess_mount,
      node_selector: { cluster: 'test' }
    }, gpus_per_node: 1)

    cmd = '/usr/bin/wontwork --kubeconfig=~/kube.config --context=ood-test-cluster ' \
          '--namespace=user-testuser -o json create -f -'
    assert_submits(batch, script, 'pod_yml_from_all_configs.yml', cmd)
  end

  def test_submit_with_default_options
    batch = basic_batch
    stub_identity(batch)

    script = submit_script({
      container: container,
      init_containers: init_containers,
      configmap: { files: [config_file] },
      mounts: ess_mount
    })

    assert_submits(batch, script, 'pod_yml_from_defaults.yml', kubectl('-o json create -f -'))
  end

  def test_submit_with_extra_supplemental_groups
    batch = basic_batch
    stub_identity(batch)
    batch.stubs(:auto_supplemental_groups).returns(true)
    batch.stubs(:default_supplemental_groups).returns([1000, 1001])

    script = submit_script({
      container: container(supplemental_groups: [1002]),
      init_containers: init_containers,
      configmap: { files: [config_file] },
      mounts: ess_mount
    })

    assert_submits(batch, script, 'pod_yml_extra_groups.yml', kubectl('-o json create -f -'))
  end

  def test_submit_with_no_mounts
    batch = basic_batch
    stub_identity(batch)

    script = submit_script({
      container: container(env: { PATH: '/usr/bin:/usr/local/bin' }),
      init_containers: init_containers,
      configmap: { files: [config_file] }
    })

    assert_submits(batch, script, 'pod_yml_no_mounts.yml', kubectl('-o json create -f -'))
  end

  def test_submit_with_no_init_containers
    batch = basic_batch
    stub_identity(batch)

    script = submit_script({
      container: container,
      configmap: { files: [config_file] },
      mounts: ess_mount
    })

    assert_submits(batch, script, 'pod_yml_no_init_container.yml', kubectl('-o json create -f -'))
  end

  def test_submit_with_subpath_configmap_mounts
    batch = basic_batch
    stub_identity(batch)

    script = submit_script({
      container: container(env: { HOME: '/my/home', PATH: '/usr/bin:/usr/local/bin' }),
      init_containers: init_containers,
      configmap: {
        files: [
          config_file.merge(init_mount_path: '/ood'),
          { filename: 'passwd', mount_path: '/etc/passwd', sub_path: 'passwd', init_mount_path: '/passwd' },
          { filename: 'group', mount_path: '/etc/group', sub_path: 'group' }
        ]
      }
    })

    assert_submits(batch, script, 'pod_yml_subpath_configmap.yml', kubectl('-o json create -f -'))
  end

  def test_submit_with_no_mounts_and_no_configmap
    batch = basic_batch
    stub_identity(batch)

    script = submit_script({
      container: container(env: { PATH: '/usr/bin:/usr/local/bin' }),
      init_containers: init_containers
    })

    assert_submits(batch, script, 'pod_yml_no_mounts_no_configmaps.yml', kubectl('-o json create -f -'))
  end

  def test_submit_with_no_configmap
    batch = basic_batch
    stub_identity(batch)

    script = submit_script({
      container: container(env: { PATH: '/usr/bin:/usr/local/bin' }),
      init_containers: init_containers,
      mounts: ess_mount
    })

    assert_submits(batch, script, 'pod_yml_no_configmaps.yml', kubectl('-o json create -f -'))
  end

  def test_submit_saves_pod_yml_to_workdir
    Dir.mktmpdir do |tmp|
      batch = basic_batch
      stub_identity(batch)

      script = submit_script({
        container: container,
        init_containers: init_containers,
        configmap: { files: [config_file] },
        mounts: ess_mount
      }, workdir: tmp)

      expected_yml = fixture('pod_yml_from_defaults.yml')
      expect_kubectl(kubectl('-o json create -f -'), stdin: expected_yml)

      batch.submit(script)

      assert_equal(expected_yml, File.read(File.join(tmp, 'pod.yml')))
    end
  end

  def test_submit_raises_with_kubectl_error
    batch = basic_batch
    stub_identity(batch)
    script = submit_script({ container: container })
    stub_kubectl(kubectl('-o json create -f -'), stdin: batch.send(:generate_id_yml, script).first,
                 stderr: 'error: unable to recognize', success: false)

    error = assert_raises(Batch::Error) { batch.submit(script) }
    assert_equal('error: unable to recognize', error.message)
  end

  def test_submit_requires_a_script
    assert_raises(ArgumentError) { basic_batch.submit(nil) }
  end

  def test_generate_id
    id = Batch.new({}).generate_id('My App')

    assert_match(/\Amy-app-[0-9a-z]{1,8}\z/, id)
  end

  # ---- delete ----

  def test_delete_removes_pod_and_supporting_resources
    batch = basic_batch
    id = 'test-pod-123'

    expect_kubectl(kubectl("delete pod #{id} --wait=false"))
    expect_kubectl(kubectl("delete service #{id}-service --wait=false"))
    expect_kubectl(kubectl("delete secret #{id}-secret --wait=false"))
    expect_kubectl(kubectl("delete configmap #{id}-configmap --wait=false"))

    batch.delete(id)
  end

  def test_delete_ignores_resources_that_dont_exist
    batch = basic_batch
    id = 'rspec-test'

    expect_kubectl(kubectl("delete pod #{id} --wait=false"), stderr: not_found('pods', id), success: false)
    expect_kubectl(kubectl("delete service #{id}-service --wait=false"), stderr: not_found('services', "#{id}-service"), success: false)
    expect_kubectl(kubectl("delete secret #{id}-secret --wait=false"), stderr: not_found('secrets', "#{id}-secret"), success: false)
    expect_kubectl(kubectl("delete configmap #{id}-configmap --wait=false"), stderr: not_found('configmaps', "#{id}-configmap"), success: false)

    batch.delete(id)
  end

  def test_delete_raises_errors_other_than_not_found
    batch = basic_batch
    errmsg = 'Error from server (Forbidden): pods "test-pod-123" is forbidden'
    stub_kubectl(kubectl('delete pod test-pod-123 --wait=false'), stderr: errmsg, success: false)

    error = assert_raises(Batch::Error) { batch.delete('test-pod-123') }
    assert_equal(errmsg, error.message)
  end

  # ---- info_all and friends ----

  def several_pods_info
    host = { host: '10.20.0.40' }
    [
      K8sJobInfo.new({ id: 'bash', status: 'completed', job_name: 'bash', job_owner: 'johrstrom',
                       dispatch_time: 1588023136, submission_time: 1588023135, wallclock_time: 300,
                       ood_connection_info: host }),
      K8sJobInfo.new({ id: 'bash-ssd', status: 'queued_held', job_name: 'bash-ssd', job_owner: 'johrstrom',
                       dispatch_time: nil, submission_time: 1588023155, wallclock_time: nil,
                       ood_connection_info: { host: nil } }),
      K8sJobInfo.new({ id: 'jupyter-3pjruck9', status: 'suspended', job_name: 'jupyter', job_owner: 'johrstrom',
                       dispatch_time: nil, submission_time: 1588106996, wallclock_time: nil,
                       ood_connection_info: host }),
      K8sJobInfo.new({ id: 'jupyter-q323v88u', status: 'running', job_name: 'jupyter', job_owner: 'johrstrom',
                       dispatch_time: 1588089059, submission_time: 1588089047, wallclock_time: 16051,
                       ood_connection_info: host })
    ]
  end

  def stub_several_pods
    freeze_now('2020-04-28 20:18:30 +0000')
    stub_kubectl(kubectl('-o json get pods'), stdout: fixture('several_pods.json'))
  end

  def test_info_all_with_no_pods
    stub_kubectl(kubectl('-o json get pods'), stdout: 'No resources found in testuser namespace.')

    assert_equal([], basic_batch.info_all)
  end

  def test_info_all_raises_errors_with_all_namespaces
    errmsg = 'Error from server (Forbidden): pods is forbidden: User "testuser" cannot list resource "pods" in API group "" at the cluster scope'
    stub_kubectl('/usr/bin/wontwork --kubeconfig=~/kube.config --context=ood-test-cluster -o json get pods --all-namespaces',
                 stderr: errmsg, success: false)

    error = assert_raises(Batch::Error) { configured_batch.info_all }
    assert_equal(errmsg, error.message)
  end

  def test_info_all_with_pods
    stub_several_pods

    assert_equal(several_pods_info, basic_batch.info_all)
  end

  def test_info_where_owner
    stub_several_pods
    batch = basic_batch

    assert_equal(several_pods_info, batch.info_where_owner('johrstrom'))
    assert_equal(several_pods_info, batch.info_where_owner(['someone', 'johrstrom'], attrs: [:id]))
    assert_equal([], batch.info_where_owner('someone'))
  end

  def test_info_all_each
    stub_several_pods
    batch = basic_batch

    assert_equal(several_pods_info, batch.info_all_each.to_a)

    yielded = []
    batch.info_all_each { |info| yielded << info }
    assert_equal(several_pods_info, yielded)
  end

  def test_info_where_owner_each
    stub_several_pods
    batch = basic_batch

    assert_equal(several_pods_info, batch.info_where_owner_each('johrstrom').to_a)

    yielded = []
    batch.info_where_owner_each('someone') { |info| yielded << info }
    assert_equal([], yielded)
  end

  # ---- info and status ----

  def stub_info(id, pod:, service: nil, secret: nil)
    freeze_now('2020-04-18 13:01:56 +0000')

    if pod
      stub_kubectl(kubectl("-o json get pod #{id}"), stdout: fixture(pod))
    else
      stub_kubectl(kubectl("-o json get pod #{id}"), stderr: not_found('pod', id), success: false)
    end

    if service
      stub_kubectl(kubectl("-o json get service #{id}-service"), stdout: fixture(service))
    else
      stub_kubectl(kubectl("-o json get service #{id}-service"), stderr: not_found('services', "#{id}-service"), success: false)
    end

    if secret
      stub_kubectl(kubectl("-o json get secret #{id}-secret"), stdout: fixture(secret))
    else
      stub_kubectl(kubectl("-o json get secret #{id}-secret"), stderr: not_found('secret', "#{id}-secret"), success: false)
    end
  end

  def running_pod_info(connection)
    K8sJobInfo.new({
      id: 'jupyter-bmurb8sa', status: OodCore::Job::Status.new(state: 'running'),
      job_name: 'jupyter', job_owner: 'johrstrom',
      dispatch_time: 1587060509, submission_time: 1587060496, wallclock_time: 154407,
      ood_connection_info: connection, procs: 1
    })
  end

  def test_info_running_pod
    stub_info('jupyter-bmurb8sa', pod: 'single_running_pod.json')
    info = basic_batch.info('jupyter-bmurb8sa')

    assert_equal(running_pod_info({ host: '10.20.0.40' }), info)
    assert_equal({ host: '10.20.0.40' }, info.ood_connection_info)
  end

  def test_info_errored_pod
    stub_info('jupyter-h6kw06ve', pod: 'single_error_pod.json')
    info = basic_batch.info('jupyter-h6kw06ve')

    expected = K8sJobInfo.new({
      id: 'jupyter-h6kw06ve', status: OodCore::Job::Status.new(state: 'suspended'),
      job_name: 'jupyter', job_owner: 'johrstrom', dispatch_time: nil,
      submission_time: 1587069112, wallclock_time: nil, ood_connection_info: { host: '10.20.0.40' }
    })
    assert_equal(expected, info)
  end

  def test_info_completed_pod
    stub_info('bash', pod: 'single_completed_pod.json')
    info = basic_batch.info('bash')

    expected = K8sJobInfo.new({
      id: 'bash', status: OodCore::Job::Status.new(state: 'completed'),
      job_name: 'bash', job_owner: 'johrstrom', dispatch_time: 1587506633,
      submission_time: 1587506632, wallclock_time: 300, ood_connection_info: { host: '10.20.0.40' }
    })
    assert_equal(expected, info)
  end

  def test_info_queued_pod
    stub_info('jupyter-28wixphq', pod: 'single_queued_pod.json')
    info = basic_batch.info('jupyter-28wixphq')

    expected = K8sJobInfo.new({
      id: 'jupyter-28wixphq', status: OodCore::Job::Status.new(state: 'queued'),
      job_name: 'jupyter', job_owner: 'johrstrom', dispatch_time: nil,
      submission_time: 1587580037, wallclock_time: nil, ood_connection_info: { host: '10.20.0.40' }
    })
    assert_equal(expected, info)
  end

  def test_info_unscheduleable_pod
    stub_info('bash', pod: 'single_unscheduleable_pod.json')
    info = basic_batch.info('bash')

    expected = K8sJobInfo.new({
      id: 'bash', status: OodCore::Job::Status.new(state: 'queued_held'),
      job_name: 'bash', job_owner: 'johrstrom', dispatch_time: nil,
      submission_time: 1587580582, wallclock_time: nil, ood_connection_info: { host: nil }, procs: 1
    })
    assert_equal(expected, info)
    assert_equal({ host: nil }, info.ood_connection_info)
  end

  def test_info_reads_connection_from_service_and_secret
    stub_info('jupyter-bmurb8sa', pod: 'single_running_pod.json',
              service: 'single_service.json', secret: 'single_secret.json')
    info = basic_batch.info('jupyter-bmurb8sa')

    connection = { host: '10.20.0.40', port: 30689, password: 'ekmfxbOgNUlmLy4m' }
    assert_equal(running_pod_info(connection), info)
    assert_equal(connection, info.ood_connection_info)
  end

  def test_info_reports_missing_pod_as_completed
    id = 'jupyter-3o4n6z3e'
    stub_info(id, pod: nil)

    assert_equal(OodCore::Job::Info.new(id: id, status: 'completed'), basic_batch.info(id))
  end

  def test_status
    stub_info('jupyter-bmurb8sa', pod: 'single_running_pod.json')

    assert(basic_batch.status('jupyter-bmurb8sa').running?)
  end

  # ---- configure_kube! ----

  def test_configure_kube_default_commands
    Batch.any_instance.expects(:call)
         .with("/usr/bin/kubectl --kubeconfig=#{Dir.home}/.kube/config config set-cluster open-ondemand --server=https://localhost:8080")
         .once

    Batch.configure_kube!({})
  end

  def test_configure_kube_default_auth_commands
    Batch.any_instance.expects(:call)
         .with("/usr/bin/kubectl --kubeconfig=#{Dir.home}/.kube/config config set-cluster open-ondemand --server=https://localhost:8080")
         .once

    Batch.configure_kube!({ auth: Batch.default_auth })
  end

  def test_configure_kube_auth_with_no_type_is_managed
    Batch.any_instance.expects(:call).once

    Batch.configure_kube!({ auth: {} })
  end

  def test_configure_kube_sets_oidc_context
    Batch.any_instance.stubs(:username).returns('jessie')
    Batch.any_instance.expects(:call).with(
      '/usr/bin/wontwork --kubeconfig=~/kube.config config set-cluster test-cluster ' \
      '--server=https://some.k8s.host --certificate-authority=/etc/some.cert'
    )
    Batch.any_instance.expects(:call).with(
      '/usr/bin/wontwork --kubeconfig=~/kube.config config set-context ood-test-cluster ' \
      '--cluster=test-cluster --namespace=user-jessie --user=dev-jessie'
    )

    Batch.configure_kube!(config)
  end

  def test_configure_kube_sets_oidc_context_named_after_cluster_by_default
    cfg = config
    cfg.delete(:context)

    Batch.any_instance.stubs(:username).returns('jessie')
    Batch.any_instance.expects(:call).with(
      '/usr/bin/wontwork --kubeconfig=~/kube.config config set-cluster test-cluster ' \
      '--server=https://some.k8s.host --certificate-authority=/etc/some.cert'
    )
    Batch.any_instance.expects(:call).with(
      '/usr/bin/wontwork --kubeconfig=~/kube.config config set-context test-cluster ' \
      '--cluster=test-cluster --namespace=user-jessie --user=dev-jessie'
    )

    Batch.configure_kube!(cfg)
  end

  def gke_config(locale)
    {
      auth: { type: 'gke', svc_acct_file: '~/.gke/acct.key' }.merge(locale),
      cluster: 'gke-cluster-oakley',
      config_file: '~/.gke/oakley.config'
    }
  end

  def expect_gke_commands(locale_flag)
    Batch.any_instance.expects(:call).with(
      '/usr/bin/kubectl --kubeconfig=~/.gke/oakley.config config set-cluster gke-cluster-oakley --server=https://localhost:8080'
    )
    Batch.any_instance.expects(:call).with('gcloud auth activate-service-account --key-file=~/.gke/acct.key')
    Batch.any_instance.expects(:call).with(
      "gcloud container clusters get-credentials #{locale_flag} gke-cluster-oakley",
      env: { 'KUBECONFIG' => '~/.gke/oakley.config' }
    )
  end

  def test_configure_kube_gke_with_region
    expect_gke_commands('--region=ohio')
    Batch.configure_kube!(gke_config(region: 'ohio'))
  end

  def test_configure_kube_gke_with_zone
    expect_gke_commands('--zone=ohio')
    Batch.configure_kube!(gke_config(zone: 'ohio'))
  end

  # ---- user identity (read from the system, not kubectl) ----

  def test_default_env_comes_from_the_current_user
    Etc.stubs(:getlogin).returns('me')
    Etc.stubs(:getpwnam).with('me').returns(User.new(dir: '/home/me', uid: 1001, gid: 1002))
    Etc.stubs(:getgrgid).with(1002).returns(Struct.new(:name).new('mygroup'))

    expected = { USER: 'me', UID: 1001, HOME: '/home/me', GROUP: 'mygroup', GID: 1002, KUBECONFIG: '/dev/null' }
    assert_equal(expected, Batch.new({}).send(:default_env))
  end

  def test_default_supplemental_groups_skip_system_groups
    groups = [1005, 10, 1001].map { |id| stub(id: id) }
    OodSupport::User.stubs(:new).returns(stub(groups: groups))

    assert_equal([1001, 1005], Batch.new({}).send(:default_supplemental_groups))
  end
end
