require "fog/openstack"
require "json"
require "ood_core/job/adapters/coder/credentials"

class OpenStackCredentials < CredentialsInterface
  def initialize(auth_url)
    @auth_url = auth_url
  end

  def load_credentials(id, username)
    file_path = "/home/#{username}/#{id}_credentials.json"
    JSON.parse(File.read(file_path))
  rescue Errno::ENOENT => e
    puts "Error loading credentials: #{e}"
    nil
  end

  def generate_credentials(project_id, username)
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
        "name": "OOD_generated_#{rand(16**8).to_s(16)}" ,
        "description": "Application credential generated via OOD for Coder.",
        "roles": [
        ],
        "unrestricted": true,
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

  def save_credentials(id, username, app_credentials)
    file_path = "/home/#{username}/#{id}_credentials.json"
    File.write(file_path, JSON.generate(app_credentials))
  end


  def destroy_credentials(os_app_credentials, deletion_status, id, username)
    return if os_app_credentials.nil?
    
  
    connection = create_fog_connection(os_app_credentials)
    credentials_to_destroy = find_os_application_credentials(connection, os_app_credentials)
  
    if deletion_status != "deleted"
      File.delete("/home/#{username}/#{id}_credentials.json")
      puts "Workspace deletion timed out, credentials with id #{os_app_credentials['id']} of user #{os_app_credentials['user_id']} were not destroyed"
      return
    end

    begin
      credentials_to_destroy.destroy
    rescue Excon::Error::Forbidden => e
      puts "Error destroying application credentials with id #{os_app_credentials['id']} #{e}"
    end
  end


  private
  def create_fog_connection(os_app_credentials)
    Fog::OpenStack::Identity.new({
      openstack_auth_url: @auth_url,
      openstack_management_url: @auth_url,
      openstack_application_credential_id: os_app_credentials['id'],
      openstack_application_credential_secret: os_app_credentials['secret']
    })
  end

  private
  def find_os_application_credentials(connection, os_app_credentials)
    connection.application_credentials.find_by_id(os_app_credentials['id'], os_app_credentials['user_id'])
  end
end