require "ood_core/refinements/hash_extensions"
require "json"
require "async/http/internet/instance"
  

# Utility class for the Coder adapter to interact with the Coders API.
class OodCore::Job::Adapters::Coder::Batch
  require_relative "coder_job_info"
  class Error < StandardError; end
  def initialize(config, credential_class)
    @host = config[:host]
    @token = config[:token]
    @service_user = config[:service_user]
    @cloud = config[:auth]["cloud"]
    @deletion_max_attempts = config[:deletion_max_attempts] || 5
    @deletion_timeout_interval_seconds = config[:deletion_timeout_interval] || 10
    @credentials = credential_class.new(config[:auth]["url"])  
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

  def submit(script)
    org_id = script.native[:org_id]
    project_id = script.native[:project_id]
    coder_parameters = script.native[:coder_parameters]
    endpoint = "#{@host}/api/v2/organizations/#{org_id}/members/#{@service_user}/workspaces"
    app_credentials = @credentials.generate_app_credentials(project_id)
    headers = get_headers(@token)
    workspace_name = "#{username}-#{script.native[:workspace_name]}-#{rand(2_821_109_907_456).to_s(36)}"
    body = {
      template_version_id: script.native[:template_version_id],
      name: workspace_name,
      rich_parameter_values: get_rich_parameters(coder_parameters, project_id, app_credentials),
    }

    resp = api_call('post', endpoint, headers, body)
    @credentials.save_credentials(resp["id"], username, app_credentials)
    resp["id"]

  end

  def delete(id)
    endpoint = "#{@host}/api/v2/workspaces/#{id}/builds"
    headers = get_headers(@token)
    body = {
      'orphan' => false,
      'transition' => 'delete'
    }
    api_call('post', endpoint, headers, body)
  
    credentials = @credentials.load_credentials(id, username)
  
    wait_for_workspace_deletion(id) do |attempt|
      puts "#{Time.now.inspect} Deleting workspace (attempt #{attempt + 1}/#{5})"
    end
  
    @credentials.destroy_app_credentials(credentials)
  end
  
  def wait_for_workspace_deletion(id)
    max_attempts = @deletion_max_attempts
    timeout_interval = @deletion_timeout_interval_seconds
  
    max_attempts.times do |attempt|
      break unless workspace_json(id) && workspace_json(id).dig("latest_build", "status") == "deleting"
      yield(attempt + 1)
      sleep(timeout_interval)
    end
  end

  def workspace_json(id)
    endpoint = "#{@host}/api/v2/workspaces/#{id}?include_deleted=true"
    headers = get_headers(@token)
    api_call('get', endpoint, headers)
  end

  def info(id)
    workspace_info_from_json(workspace_json(id))
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

  def build_coder_job_info(json_data, status)
    coder_output_metadata = json_data["latest_build"]["resources"]
    &.find { |resource| resource["name"] == "coder_output" }
    &.dig("metadata")
    coder_output_hash = coder_output_metadata&.map { |meta| [meta["key"].to_sym, meta["value"]] }&.to_h || {}
    OodCore::Job::Adapters::Coder::CoderJobInfo.new(**{
      id: json_data["id"],
      job_name: json_data["workspace_name"],
      status: OodCore::Job::Status.new(state: status),
      job_owner: json_data["workspace_owner_name"],
      submission_time: json_data["created_at"],
      dispatch_time: json_data.dig("updated_at"),
      wallclock_time: wallclock_time(json_data, status),
      ood_connection_info: { host: coder_output_hash[:floating_ip], port: 80 },
      native: coder_output_hash
  })
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

  def workspace_info_from_json(json_data)
    state = json_data.dig("latest_build", "status") || json_data.dig("latest_build", "job", "status")
    status = coder_state_to_ood_status(state)
    build_coder_job_info(json_data, status)
  end

  def api_call(method, endpoint, headers, body = nil)
    uri = URI(endpoint)
    Sync do
      case method.downcase
      when 'get'
        function = Async::HTTP::Internet::method(:get)
      when 'post'
        function = Async::HTTP::Internet::method(:post)
      when 'delete'
        function = Async::HTTP::Internet::method(:delete)
      else
        raise ArgumentError, "Invalid HTTP method: #{method}"
      end

      body = body.to_json if body
      response = function.call(uri, headers, body)

      if response.success?
        JSON.parse(response.read)
      else
        raise Error, "HTTP Error: #{response.status} #{response.read}  for request #{endpoint} and body #{body}"
      end
    end
  end

  def username
    @username ||= Etc.getlogin
  end

end
