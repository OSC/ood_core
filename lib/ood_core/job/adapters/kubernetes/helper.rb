class OodCore::Job::Adapters::Kubernetes::Helper

  require 'ood_core/job/adapters/kubernetes/resources'

  def info_from_json(pod_json: nil, service_json: nil, secret_json: nil)
    pod_hash = pod_info_from_json(pod_json)
    service_hash = service_info_from_json(service_json)
    secret_hash = secret_info_from_json(secret_json)

    # can't just use deep_merge bc we don't depend *directly* on rails
    pod_hash[:native] = pod_hash[:native].merge(service_hash[:native])
    pod_hash[:native] = pod_hash[:native].merge(secret_hash[:native])
    OodCore::Job::Info.new(pod_hash)
  end

  def container_from_native(native)
    container = native.fetch(:container)
    # TODO: throw the right error here telling folks what they
    # need to implement if a fetch KeyError is thrown
    OodCore::Job::Adapters::Kubernetes::Resources::Container.new(
      container[:name],
      container[:image],
      parse_command(container[:command]),
      container[:port]
    )
  end

  def parse_command(cmd)
    command = cmd&.split(' ')
    command.nil? ? [] : command
  end

  def configmap_from_native(native, id)
    configmap = native.fetch(:configmap, nil)
    return nil if configmap.nil?

    OodCore::Job::Adapters::Kubernetes::Resources::ConfigMap.new(
      configmap_name(id),
      configmap[:filename],
      configmap[:data]
    )
  end

  def init_ctrs_from_native(native_data)
    init_ctrs = []
    return init_ctrs unless native_data.key?(:init_ctrs)

    ctrs = native_data[:init_ctrs]
    ctrs.each do |ctr_raw|
      ctr = OodCore::Job::Adapters::Kubernetes::Resources::Container.new(
        ctr_raw[:name],
        ctr_raw[:image],
        ctr_raw[:command].to_a
      )
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

  private 

  def pod_info_from_json(json_data)
    return {} if json_data.nil?

    # passing json_data around like it's OK, probably should check for nil?
    id = json_data.dig(:metadata, :name).to_s
    {
      id: id,
      job_name: name_from_metadata(json_data.dig(:metadata)),
      status: pod_status_from_json(json_data),
      job_owner: json_data.dig(:metadata, :namespace).to_s,
      submission_time: submission_time(json_data),
      dispatch_time: dispatch_time(json_data),
      wallclock_time: wallclock_time(json_data),
      native: {
        host: json_data.dig(:status, :hostIP)
      }
    }
  end

  def name_from_metadata(metadata)
    name = metadata.dig(:labels, :'app.kubernetes.io/name')
    name = metadata.dig(:labels, :'k8s-app') if name.nil?
    name = metadata.dig(:name) if name.nil? # pod-id but better than nil?
    name
  end

  def service_info_from_json(json_data)
    # .spec.ports[0].nodePort
    ports = json_data.dig(:spec, :ports)
    {
      native:
        {
          port: ports[0].dig(:nodePort)
        }
    }
  rescue
    empty_native
  end

  def secret_info_from_json(json_data)
    raw = json_data.dig(:data, :password)
    {
      native:
        {
          password: Base64.decode64(raw)
        }
    }
  rescue
    empty_native
  end

  def empty_native
    {
      native: {}
    }
  end

  def dispatch_time(json_data)
    status = pod_status_from_json(json_data)
    state_data = json_data.dig(:status, :containerStatuses)[0].dig(:state)
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
    state_data = json_data.dig(:status, :containerStatuses)[0].dig(:state)
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
    str = json_data.dig(:status, :startTime)
    DateTime.parse(str).to_time.to_i
  end

  def pod_status_from_json(json_data)
    container_statuses = json_data.dig(:status, :containerStatuses)
    json_state = container_statuses[0].dig(:state) # only support 1 container/pod

    state = 'undetermined'
    state = 'running' unless json_state.dig(:running).nil?
    state = 'completed' unless json_state.dig(:terminated).nil?
    state = 'queued' unless json_state.dig(:waiting).nil?

    OodCore::Job::Status.new(state: state)
  end

end