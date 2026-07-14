require "ood_core/refinements/hash_extensions"
require "json"

# Utility class for the Coder adapter to interact with the Coders API.
class OodCore::Job::Adapters::Coder::Batch
  require_relative "coder_job_info"
  class Error < StandardError; end
  def initialize(config, credentials)
    @host = config[:host]
    @token = config[:token]
    @service_user = config[:service_user]
    @deletion_max_attempts = config[:deletion_max_attempts] || 5
    @deletion_timeout_interval_seconds = config[:deletion_timeout_interval] || 10
    @credentials = credentials 
  end

  def get_rich_parameters(coder_parameters, project_id, app_credentials)
    rich_parameter_values = [
      { name: "application_credential_name", value: app_credentials[:name] },
      { name: "application_credential_id", value: app_credentials[:id] },
      { name: "application_credential_secret", value: app_credentials[:secret] },
      {name: "project_id", value: project_id }
    ]
    if coder_parameters
      coder_parameters.each do |key, value|
        rich_parameter_values << { name: key, value: value.to_s}
      end
    end
    rich_parameter_values
  end

  def get_headers(coder_token)
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'Coder-Session-Token' => coder_token
    }
  end

  def generate_coder_workspace_name(submitted_name)
    "#{username}-#{submitted_name}-#{rand(2_821_109_907_456).to_s(36)}"
  end 
  def submit(script)
    project_id = script.native[:project_id]
    app_credentials = @credentials.generate_credentials(project_id)
    workspace_name = generate_coder_workspace_name(script.native[:workspace_name])
   
    create_coder_workspace(
      script.native[:org_id],
      project_id,
      script.native[:template_version_id],
      script.native[:coder_parameters],
      app_credentials,
      workspace_name)

    @credentials.save_credentials(workspace_name, app_credentials)
    workspace_name
  end

  def create_coder_workspace(org_id, project_id, template_version_id, coder_parameters, app_credentials, name)
    endpoint = "#{@host}/api/v2/organizations/#{org_id}/members/#{@service_user}/workspaces"
    headers = get_headers(@token)
    body = {
      template_version_id: template_version_id,
      name: name,
      rich_parameter_values: get_rich_parameters(coder_parameters, project_id, app_credentials),
    }
    api_call('post', endpoint, headers, body)
  end


  def delete_coder_workspace(id)
    build_id = get_workspace_info(id)["id"]

    endpoint = "#{@host}/api/v2/workspaces/#{build_id}/builds"
    headers = get_headers(@token)
    body = {
      'orphan' => false,
      'transition' => 'delete'
    }
    api_call('post', endpoint, headers, body)
  end
  
  def delete(id)
    delete_coder_workspace(id)

    credentials = @credentials.load_credentials(id)
    puts "credentials loaded #{credentials["id"]}" 
    wait_for_workspace_deletion(id) do |attempt|
      puts "#{Time.now.inspect} Deleting workspace (attempt #{attempt}/#{5})"
    end
    workspace_info = get_workspace_info(id)
    @credentials.destroy_credentials(credentials, workspace_status(workspace_info), id)
  end
  
  def wait_for_workspace_deletion(id)
    max_attempts = @deletion_max_attempts
    timeout_interval = @deletion_timeout_interval_seconds
  
    max_attempts.times do |attempt|
      workspace_info = get_workspace_info(id)
      break unless workspace_info && workspace_status(workspace_info) == "deleting"
      yield(attempt + 1)
      sleep(timeout_interval)
    end
  end
  def workspace_status(workspace_info)
    workspace_info.dig("latest_build", "status")
  end
  def parse_error_logs(logs_array)    
    logs_array
    .reject { |n| n["output"].to_s.empty?}
    .map { |n| n["output"].scan(/"message":\s*"([^"]+)"/)[0] }
    .reject {|n| n.nil?}
  end
  
  def get_workspace_info(id)
    endpoint = "#{@host}/api/v2/users/#{@service_user}/workspace/#{id}?include_deleted=true"
    headers = get_headers(@token)
    api_call('get', endpoint, headers)
  end

  def read_coder_output(latest_build)
    coder_output_metadata = latest_build.dig("resources")
    &.find { |resource| resource["name"] == "coder_output" }
    &.dig("metadata")
    coder_output_metadata&.map { |meta| [meta["key"].to_sym, meta["value"]] }&.to_h || {}
  end 

  def info(id)
    workspace_info = get_workspace_info(id)
    latest_build = workspace_info.dig("latest_build")
    coder_status = workspace_status(workspace_info) || latest_build.dig("job", "status")
    ood_status = coder_state_to_ood_status(coder_status)
    coder_output_hash = read_coder_output(latest_build)
    build_logs = get_build_logs(latest_build.dig("id"))
    error_logs = parse_error_logs(build_logs)
    OodCore::Job::Adapters::Coder::CoderJobInfo.new(**{
      id: workspace_info["id"],
      job_name: workspace_info["workspace_name"],
      status: OodCore::Job::Status.new(state: ood_status),
      job_owner: workspace_info["workspace_owner_name"],
      submission_time: workspace_info["created_at"],
      dispatch_time: workspace_info.dig("updated_at"),
      wallclock_time: wallclock_time(workspace_info, ood_status),
      ood_connection_info: { host: coder_output_hash[:floating_ip], port: 80, error_logs: error_logs},
      native: coder_output_hash
  })
  end

  def coder_state_to_ood_status(coder_state)
    case coder_state
    when "starting"
      "queued"
    when "failed"
      "suspended"
    when "running"
      "running"
    when "deleted"
      "completed"
    when "stopped"
      "completed"
    else
      "undetermined"
    end
  end

  def get_build_logs(build_id)
    endpoint = "#{@host}/api/v2/workspacebuilds/#{build_id}/logs"
    headers = get_headers(@token)
    api_call('get', endpoint, headers)
  end

  def wallclock_time(json_data, status)
    start_time = start_time(json_data) 
    end_time = end_time(json_data, status)
    end_time - start_time
  end  

  def start_time(json_data)
    start_time_string = json_data.dig("updated_at")
    DateTime.parse(start_time_string).to_time.to_i
  end 
 
  def end_time(json_data, status)
    if status == 'deleted'
      end_time_string = json_data["latest_build"].dig("updated_at") 
      et = DateTime.parse(end_time_string).to_time.to_i
    else
      et = DateTime.now.to_time.to_i
    end
    et
  end

  def api_call(method, endpoint, headers, body = nil)
    uri = URI(endpoint)
    case method.downcase
    when 'get'
      request = Net::HTTP::Get.new(uri, headers)
    when 'post'
      request = Net::HTTP::Post.new(uri, headers)
    when 'delete'
      request = Net::HTTP::Delete.new(uri, headers)
    else
      raise ArgumentError, "Invalid HTTP method: #{method}"
    end

    request.body = body.to_json if body
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    else
      raise Error, "HTTP Error: #{response.code} #{response.message}  for request #{endpoint} and body #{body}"
    end
  end

  def username
    @username ||= Etc.getlogin
  end

end
