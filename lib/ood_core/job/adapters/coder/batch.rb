require "ood_core/refinements/hash_extensions"
require "json"

Dir.glob('/var/lib/gems/3.1.0/gems/*').each do |dir|
  if File.directory?(dir) && dir.end_with?('-lib') == false
    $LOAD_PATH.unshift("#{dir}/lib")
  end
end

require "fog/openstack"
  
# Utility class for the Coder adapter to interact with the Coders API.
class OodCore::Job::Adapters::Coder::Batch
  require_relative "coder_job_info"
  class Error < StandardError; end
  def initialize(config)
    @host = config[:host]
    @token = config[:token]
@service_user = config[:service_user]
    @auth_url = config[:auth]["url"]
    @cloud = config[:auth]["cloud"] 
 end

  def generate_os_app_credentials(project_id)
    token_json = JSON.parse(File.read("/home/#{username}/token.json"))
    access_token = token_json["id"]
    user_id = token_json["user_id"]
    connection = Fog::OpenStack::Identity.new({
      openstack_auth_url: @auth_url,
      openstack_management_url: @auth_url,
      openstack_auth_token: access_token,
    })

    auth = {
      "auth": {
          "identity": {
              "methods": [
                  "token"
              ],
              "token": {
                  "id": access_token
              }
          },
          "scope": {
              "project": {
                  "id": project_id
              }
          }
      }
    }

    scoped_token = connection.tokens.authenticate(auth)


    connection = Fog::OpenStack::Identity.new({
      openstack_auth_url: @auth_url,
      openstack_management_url: @auth_url,
      openstack_auth_token: scoped_token,
    })


    app_credentials = {
        "name": "OOD generated credentials",
        "description": "Application credential generated via OOD for Coder.",
        "roles": [
           {"id": "be47e8625feb46aebff445ce8f95af8f"},
           {"id": "59f1477385ec4baa8cc4e645c81473a0"}
        ],
        "unrestricted": false,
        "user_id": user_id
    }
    res = connection.application_credentials.create app_credentials

    credential_data = {
      id: res.id,
      name: res.name,
      user_id: user_id,
      secret: res.secret
    }

    credential_data
  end

  def get_rich_parameters(coder_parameters, project_id, os_app_credentials)
    rich_parameter_values = [
      { name: "application_credential_name", value: os_app_credentials[:name] },
      { name: "application_credential_id", value: os_app_credentials[:id] },
      { name: "application_credential_secret", value: os_app_credentials[:secret] },
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
    os_app_credentials = generate_os_app_credentials(project_id)
    headers = get_headers(@token)
    body = {
      template_id: script.native[:template_id],
      template_version_name: script.native[:template_version_name],
      name: "#{username}-#{script.native[:workspace_name]}-#{rand(2_821_109_907_456).to_s(36)}",
      rich_parameter_values: get_rich_parameters(coder_parameters, project_id, os_app_credentials),
    }

    resp = api_call('post', endpoint, headers, body)
    File.write("/home/#{username}/#{resp["id"]}_credentials.json", JSON.generate(os_app_credentials))
    resp["id"]

  end

  def delete(id)

    endpoint = "#{@host}/api/v2/workspaces/#{id}/builds"
    headers = get_headers(@token)
    body = {
      'orphan' => false,
      'transition' => 'delete'
    }
    res = api_call('post', endpoint, headers, body)

    os_app_credentials = JSON.parse(File.read("/home/#{username}/#{id}_credentials.json"))
    connection = Fog::OpenStack::Identity.new({
      openstack_auth_url: @auth_url,
      openstack_management_url: @auth_url,
      openstack_application_credential_id: os_app_credentials['id'],
      openstack_application_credential_secret: os_app_credentials['secret'],
    })
    credentials_to_destroy = connection.application_credentials.find_by_id(os_app_credentials['id'], os_app_credentials['user_id'])
begin
    credentials_to_destroy.destroy
rescue Excon::Error::Forbidden => e
      puts "Error destroying application credentials with id #{os_app_credentials['id']} #{e}"
    end
    File.delete("/home/#{username}/#{id}_credentials.json")
  end

  def info(id)
    endpoint = "#{@host}/api/v2/workspaces/#{id}?include_deleted=true"
    headers = get_headers(@token)
    workspace_info_from_json(api_call('get', endpoint, headers))
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
