class OodCore::Job::Adapters::Kubernetes::Helper

  require_relative 'resources'
  require_relative 'k8s_job_info'
  require 'resolv'
  require 'base64'
  require 'active_support/core_ext/hash'

  class K8sDataError < StandardError; end

  Resources = OodCore::Job::Adapters::Kubernetes::Resources
  K8sJobInfo = OodCore::Job::Adapters::Kubernetes::K8sJobInfo

  # Extract info from json data. The data is expected to be from the kubectl
  # command and conform to kubernetes' datatype structures.
  #
  # Returns { ood_connection_info: {host: localhost, port:80, password: sshhh }} in the
  # extended info object field in lieu of writing a connection.yml
  #
  # @param pod_json [#to_h]
  #   the pod data returned from 'kubectl get pod abc-123'
  # @param service_json [#to_h]
  #   the service data returned from 'kubectl get service abc-123-service'
  # @param secret_json [#to_h]
  #   the secret data returned from 'kubectl get secret abc-123-secret'
  # @param ns_prefix [#to_s]
  #   the namespace prefix so that namespaces can be converted back to usernames
  # @return [OodCore::Job::ExtendedInfo]
  def info_from_json(pod_json: nil, service_json: nil, secret_json: nil, ns_prefix: nil)
    pod_hash = pod_info_from_json(pod_json, ns_prefix: ns_prefix)
    service_hash = service_info_from_json(service_json)
    secret_hash = secret_info_from_json(secret_json)

    pod_hash.deep_merge!(service_hash)
    pod_hash.deep_merge!(secret_hash)
    K8sJobInfo.new(pod_hash)
  rescue NoMethodError
    raise K8sDataError, "unable to read data correctly from json"
  end

  # Turn a container hash into a Kubernetes::Resources::Container
  #
  # @param container [#to_h]
  #   the input container hash
  # @return  [OodCore::Job::Adapters::Kubernetes::Resources::Container]
  def container_from_native(container)
    Resources::Container.new(
      container[:name],
      container[:image],
      command: parse_command(container[:command]),
      port: container[:port],
      env: container.fetch(:env, []),
      memory: container[:memory],
      cpu: container[:cpu],
      working_dir: container[:working_dir],
      restart_policy: container[:restart_policy]
    )
  end

  # Parse a command string given from a user and return an array.
  # If given an array, the input is simply returned back.
  #
  # @param cmd [#to_s]
  #   the command to parse
  # @return [Array<#to_s>]
  #   the command parsed into an array of arguements
  def parse_command(cmd)
    if cmd&.is_a?(Array)
      cmd
    else
      Shellwords.split(cmd.to_s)
    end
  end

  # Turn a configmap hash into a Kubernetes::Resources::ConfigMap
  # that can be used in templates. Needs an id so that the resulting
  # configmap has a known name.
  #
  # @param native [#to_h]
  #   the input configmap hash
  # @param id [#to_s]
  #   the id to use for giving the configmap a name
  # @return  [OodCore::Job::Adapters::Kubernetes::Resources::ConfigMap]
  def configmap_from_native(native, id)
    configmap = native.fetch(:configmap, nil)
    return nil if configmap.nil?

    Resources::ConfigMap.new(
      configmap_name(id),
      configmap[:filename],
      configmap[:data]
    )
  end

  # parse initialization containers from native data
  #
  # @param native_data [#to_h]
  #   the native data to parse. Expected key init_ctrs and for that
  #   key to be an array of hashes.
  # @return [Array<OodCore::Job::Adapters::Kubernetes::Resources::Container>]
  #   the array of init containers
  def init_ctrs_from_native(ctrs)
    init_ctrs = []

    ctrs&.each do |ctr_raw|
      ctr = container_from_native(ctr_raw)
      init_ctrs.push(ctr)
    end

    init_ctrs
  end

  def service_name(id)
    id + '-service'
  end

  def secret_name(id)
    id + '-secret'
  end

  def configmap_name(id)
    id + '-configmap'
  end

  def seconds_to_duration(s)
    "%02dh%02dm%02ds" % [s / 3600, s / 60 % 60, s % 60]
  end

  # Extract pod info from json data. The data is expected to be from the kubectl
  # command and conform to kubernetes' datatype structures.
  #
  # @param json_data [#to_h]
  #   the pod data returned from 'kubectl get pod abc-123'
  # @param ns_prefix [#to_s]
  #   the namespace prefix so that namespaces can be converted back to usernames
  # @return [#to_h]
  #   the hash of info expected from adapters
  def pod_info_from_json(json_data, ns_prefix: nil)
    {
      id: json_data.dig(:metadata, :name).to_s,
      job_name: name_from_metadata(json_data.dig(:metadata)),
      status: pod_status_from_json(json_data),
      job_owner: job_owner_from_json(json_data, ns_prefix),
      submission_time: submission_time(json_data),
      dispatch_time: dispatch_time(json_data),
      wallclock_time: wallclock_time(json_data),
      ood_connection_info: { host: get_host(json_data.dig(:status, :hostIP)) },
      procs: procs_from_json(json_data)
    }
  rescue NoMethodError
    # gotta raise an error because Info.new will throw an error if id is undefined
    raise K8sDataError, "unable to read data correctly from json"
  end

  private

  def get_host(ip)
    Resolv.getname(ip)
  rescue Resolv::ResolvError
    ip
  end

  def name_from_metadata(metadata)
    name = metadata.dig(:labels, :'app.kubernetes.io/name')
    name = metadata.dig(:labels, :'k8s-app') if name.nil?
    name = metadata.dig(:name) if name.nil? # pod-id but better than nil?
    name
  end

  def service_info_from_json(json_data)
    # all we need is the port - .spec.ports[0].nodePort
    ports = json_data.dig(:spec, :ports)
    { ood_connection_info: { port: ports[0].dig(:nodePort) } }
  rescue
    {}
  end

  def secret_info_from_json(json_data)
    raw = json_data.dig(:data, :password)
    { ood_connection_info: { password: Base64.decode64(raw) } }
  rescue
    {}
  end

  def dispatch_time(json_data)
    status = pod_status_from_json(json_data)
    container_statuses = json_data.dig(:status, :containerStatuses)
    return nil if container_statuses.nil?

    state_data = container_statuses[0].dig(:state)
    date_string = nil

    if status == 'completed'
      date_string = state_data.dig(:terminated, :startedAt)
    elsif status == 'running'
      date_string = state_data.dig(:running, :startedAt)
    end

    date_string.nil? ? nil : DateTime.parse(date_string).to_time.to_i
  end

  def wallclock_time(json_data)
    status = pod_status_from_json(json_data)
    container_statuses = json_data.dig(:status, :containerStatuses)
    return nil if container_statuses.nil?

    state_data = container_statuses[0].dig(:state)
    start_time = dispatch_time(json_data)
    return nil if start_time.nil?

    et = end_time(status, state_data)

    et.nil? ? nil : et - start_time
  end

  def end_time(status, state_data)
    if status == 'completed'
      end_time_string = state_data.dig(:terminated, :finishedAt)
      et = DateTime.parse(end_time_string).to_time.to_i
    elsif status == 'running'
      et = DateTime.now.to_time.to_i
    else
      et = nil
    end

    et
  end

  def submission_time(json_data)
    status = json_data.dig(:status)
    start = status.dig(:startTime)

    if start.nil?
      # the pod is in some pending state limbo
      conditions = status.dig(:conditions)
      # best guess to start time is just the first condition's
      # transition time
      str = conditions[0].dig(:lastTransitionTime)
    else
      str = start
    end

    DateTime.parse(str).to_time.to_i
  end

  def pod_status_from_json(json_data)
    phase = json_data.dig(:status, :phase)
    state = case phase
            when "Running"
              "running"
            when "Pending"
              "queued"
            when "Failed"
              "suspended"
            when "Succeeded"
              "completed"
            when "Unknown"
              "undetermined"
            else
              "undetermined"
            end

    OodCore::Job::Status.new(state: state)
  end

  def terminated_state(status)
    reason = status.dig(:terminated, :reason)
    if reason == 'Error'
      'suspended'
    else
      'completed'
    end
  end

  def procs_from_json(json_data)
    containers = json_data.dig(:spec, :containers)
    resources = containers[0].dig(:resources)

    cpu = resources.dig(:limits, :cpu)
    millicores_rex = /(\d+)m/

    # ok to return string bc nil.to_i == 0 and we'd rather return
    # nil (undefined) than 0 which is confusing.
    if millicores_rex.match?(cpu)
      millicores =  millicores_rex.match(cpu)[1].to_i

      # have to return at least 1 bc 200m could be 0
      ((millicores + 1000) / 1000).to_s
    else
      cpu
    end
  end

  def job_owner_from_json(json_data = {}, ns_prefix = nil)
    namespace = json_data.dig(:metadata, :namespace).to_s
    namespace.delete_prefix(ns_prefix.to_s)
  end
end
