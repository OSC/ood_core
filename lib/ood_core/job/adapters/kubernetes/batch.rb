require "ood_core/refinements/hash_extensions"
require "json"

class OodCore::Job::Adapters::Kubernetes::Batch

  require_relative "helper"
  require_relative "k8s_job_info"

  using OodCore::Refinements::HashExtensions

  class Error < StandardError; end
  class NotFoundError < StandardError; end

  attr_reader :config_file, :bin, :cluster, :mounts
  attr_reader :all_namespaces, :using_context, :helper
  attr_reader :username_prefix, :namespace_prefix
  attr_reader :auto_supplemental_groups

  def initialize(options = {})
    options = options.to_h.symbolize_keys

    @config_file = options.fetch(:config_file, default_config_file)
    @bin = options.fetch(:bin, '/usr/bin/kubectl')
    @cluster = options.fetch(:cluster, 'open-ondemand')
    @mounts = options.fetch(:mounts, []).map { |m| m.to_h.symbolize_keys }
    @all_namespaces = options.fetch(:all_namespaces, false)
    @username_prefix = options.fetch(:username_prefix, '')
    @namespace_prefix = options.fetch(:namespace_prefix, '')
    @auto_supplemental_groups = options.fetch(:auto_supplemental_groups, false)

    @using_context = false
    @helper = OodCore::Job::Adapters::Kubernetes::Helper.new

    begin
      make_kubectl_config(options)
    rescue
      # FIXME could use a log here
      # means you couldn't 'kubectl set config'
    end
  end

  def resource_file(resource_type = 'pod')
    File.dirname(__FILE__) + "/templates/#{resource_type}.yml.erb"
  end

  def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
    raise ArgumentError, 'Must specify the script' if script.nil?

    resource_yml, id = generate_id_yml(script)
    if !script.workdir.nil? && Dir.exist?(script.workdir)
      File.open(File.join(script.workdir, 'pod.yml'), 'w') { |f| f.write resource_yml }
    end
    call("#{formatted_ns_cmd} create -f -", stdin: resource_yml)

    id
  end

  def generate_id(name)
    # 2_821_109_907_456 = 36**8
    name.downcase.tr(' ', '-') + '-' + rand(2_821_109_907_456).to_s(36)
  end

  def info_all(attrs: nil)
    cmd = if all_namespaces
            "#{base_cmd} get pods -o json --all-namespaces"
          else
            "#{namespaced_cmd} get pods -o json"
          end

    output = call(cmd)
    all_pods_to_info(output)
  end

  def info_where_owner(owner, attrs: nil)
    owner = Array.wrap(owner).map(&:to_s)

    # must at least have job_owner to filter by job_owner
    attrs = Array.wrap(attrs) | [:job_owner] unless attrs.nil?

    info_all(attrs: attrs).select { |info| owner.include? info.job_owner }
  end

  def info_all_each(attrs: nil)
    return to_enum(:info_all_each, attrs: attrs) unless block_given?

    info_all(attrs: attrs).each do |job|
      yield job
    end
  end

  def info_where_owner_each(owner, attrs: nil)
    return to_enum(:info_where_owner_each, owner, attrs: attrs) unless block_given?

    info_where_owner(owner, attrs: attrs).each do |job|
      yield job
    end
  end

  def info(id)
    pod_json = safe_call('get', 'pod', id)
    return OodCore::Job::Info.new({ id: id, status: 'completed' }) if pod_json.empty?

    service_json = safe_call('get', 'service', service_name(id))
    secret_json = safe_call('get', 'secret', secret_name(id))

    helper.info_from_json(pod_json: pod_json, service_json: service_json, secret_json: secret_json)
  end

  def status(id)
    info(id).status
  end

  def delete(id)
    safe_call("delete", "pod", id)
    safe_call("delete", "service", service_name(id))
    safe_call("delete", "secret", secret_name(id))
    safe_call("delete", "configmap", configmap_name(id))
  end

  private

  def safe_call(verb, resource, id)
    begin
      case verb.to_s
      when "get"
        call_json_output('get', resource, id)
      when "delete"
        call("#{namespaced_cmd} delete #{resource} #{id} --wait=false")
      end
    rescue NotFoundError
      {}
    end
  end

  # helper to help format multi-line yaml data from the submit.yml into 
  # mutli-line yaml in the pod.yml.erb
  def config_data_lines(data)
    output = []
    first = true

    data.to_s.each_line do |line|
      output.append(first ? line : line.prepend("    "))
      first = false
    end

    output
  end

  def username
    @username ||= Etc.getlogin
  end

  def k8s_username
    "#{username_prefix}#{username}"
  end

  def user
    @user ||= Etc.getpwnam(username)
  end

  def home_dir
    user.dir
  end

  def run_as_user
    user.uid
  end

  def run_as_group
    user.gid
  end

  def fs_group
    run_as_group
  end

  def group
    Etc.getgrgid(run_as_group).name
  end

  def default_supplemental_groups
    OodSupport::User.new.groups.sort_by(&:id).map(&:id).reject { |id| id < 1000 }
  end

  def supplemental_groups(groups = [])
    sgroups = []
    if auto_supplemental_groups
      sgroups.concat(default_supplemental_groups)
    end
    sgroups.concat(groups.to_a)
    sgroups.uniq.sort
  end

  def default_env
    {
      USER: username,
      UID: run_as_user,
      HOME: home_dir,
      GROUP: group,
      GID: run_as_group,
      KUBECONFIG: '/dev/null',
    }
  end

  # helper to template resource yml you're going to submit and
  # create an id.
  def generate_id_yml(script)
    native_data = script.native
    native_data[:container][:supplemental_groups] = supplemental_groups(native_data[:container][:supplemental_groups])
    container = helper.container_from_native(native_data[:container], default_env)
    id = generate_id(container.name)
    configmap = helper.configmap_from_native(native_data, id, script.content)
    init_containers = helper.init_ctrs_from_native(native_data[:init_containers], container.env)
    spec = OodCore::Job::Adapters::Kubernetes::Resources::PodSpec.new(container, init_containers: init_containers)
    all_mounts = native_data[:mounts].nil? ? mounts : mounts + native_data[:mounts]
    node_selector = native_data[:node_selector].nil? ? {} : native_data[:node_selector]
    gpu_type = native_data[:gpu_type].nil? ? "nvidia.com/gpu" : native_data[:gpu_type]

    template = ERB.new(File.read(resource_file), nil, '-')

    [template.result(binding), id]
  end

  # helper to call kubectl and get json data back.
  # verb, resrouce and id are the kubernetes parlance terms.
  # example: 'kubectl get pod my-pod-id' is verb=get, resource=pod
  # and  id=my-pod-id
  def call_json_output(verb, resource, id, stdin: nil)
    cmd = "#{formatted_ns_cmd} #{verb} #{resource} #{id}"
    data = call(cmd, stdin: stdin)
    data = data.empty? ? '{}' : data
    json_data = JSON.parse(data, symbolize_names: true)

    json_data
  end

  def service_name(id)
    helper.service_name(id)
  end

  def secret_name(id)
    helper.secret_name(id)
  end

  def configmap_name(id)
    helper.configmap_name(id)
  end

  def namespace
    "#{namespace_prefix}#{username}"
  end

  def context
    cluster
  end

  def default_config_file
    (ENV['KUBECONFIG'] || "#{Dir.home}/.kube/config")
  end

  def default_auth
    {
      type: 'managaged'
    }.symbolize_keys
  end

  def default_server
    {
      endpoint: 'https://localhost:8080',
      cert_authority_file: nil
    }.symbolize_keys
  end

  def formatted_ns_cmd
    "#{namespaced_cmd} -o json"
  end

  def namespaced_cmd
    "#{base_cmd} --namespace=#{namespace}"
  end

  def base_cmd
    base = "#{bin} --kubeconfig=#{config_file}"
    base << " --context=#{context}" if using_context
    base
  end

  def all_pods_to_info(data)
    json_data = JSON.parse(data, symbolize_names: true)
    pods = json_data.dig(:items)

    info_array = []
    pods.each do |pod|
      info = pod_info_from_json(pod)
      info_array.push(info) unless info.nil?
    end

    info_array
  rescue JSON::ParserError
    # 'no resources in <namespace>' throws parse error
    []
  end

  def pod_info_from_json(pod)
    hash = helper.pod_info_from_json(pod)
    K8sJobInfo.new(hash)
  rescue Helper::K8sDataError
    # FIXME: silently eating error, could probably use a logger
    nil
  end

  def make_kubectl_config(config)
    set_cluster(config.fetch(:server, default_server).to_h.symbolize_keys)
    configure_auth(config.fetch(:auth, default_auth).to_h.symbolize_keys)
  end

  def configure_auth(auth)
    type = auth.fetch(:type)
    return if managed?(type)

    case type
    when 'gke'
      set_gke_config(auth)
    when 'oidc'
      set_context
    end
  end

  def use_context
    @using_context = true
  end

  def managed?(type)
    if type.nil?
      true # maybe should be false?
    else
      type.to_s == 'managed'
    end
  end

  def set_gke_config(auth)
    cred_file = auth.fetch(:svc_acct_file)

    cmd = "gcloud auth activate-service-account --key-file=#{cred_file}"
    call(cmd)

    set_gke_credentials(auth)
  end

  def set_gke_credentials(auth)

    zone = auth.fetch(:zone, nil)
    region = auth.fetch(:region, nil)

    locale = ''
    locale = "--zone=#{zone}" unless zone.nil?
    locale = "--region=#{region}" unless region.nil?

    # gke cluster name can probably can differ from what ood calls the cluster
    cmd = "gcloud container clusters get-credentials #{locale} #{cluster}"
    env = { 'KUBECONFIG' => config_file }
    call(cmd, env)
  end

  def set_context
    cmd = "#{base_cmd} config set-context #{cluster}"
    cmd << " --cluster=#{cluster} --namespace=#{namespace}"
    cmd << " --user=#{k8s_username}"

    call(cmd)
    use_context
  end

  def set_cluster(config)
    server = config.fetch(:endpoint)
    cert = config.fetch(:cert_authority_file, nil)

    cmd = "#{base_cmd} config set-cluster #{cluster}"
    cmd << " --server=#{server}"
    cmd << " --certificate-authority=#{cert}" unless cert.nil?

    call(cmd)
  end

  def call(cmd = '', env: {}, stdin: nil)
    o, e, s = Open3.capture3(env, cmd, stdin_data: stdin.to_s)
    s.success? ? o : interpret_and_raise(e)
  end

  def interpret_and_raise(stderr)
    raise NotFoundError, stderr if /^Error from server \(NotFound\):/.match(stderr)
    raise(Error, stderr)
  end
end
