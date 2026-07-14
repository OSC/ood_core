require "fog/openstack"
require "json"
require "etc"

module OodCore
  class OpenStackHelper
    attr_reader :auth_url, :openstack_instance

    def initialize(token_file:, openstack_instance:)
      @token_file = token_file
      @openstack_instance = openstack_instance
      @auth_url = "https://identity.#{openstack_instance}/v3"
    end

    # Load token data from the token file
    # @return [Hash] Parsed token JSON or nil if file does not exist
    def load_token_data
      return nil unless File.exist?(@token_file)
      JSON.parse(File.read(@token_file))
    rescue Errno::ENOENT => e
      puts "Error loading token: #{e}"
      nil
    end

    # Get access token from loaded credentials
    # @return [String] The token ID
    def access_token
      load_token_data&.[]("id")
    end

    # Get user ID from loaded credentials
    # @return [String] The user ID
    def user_id
      load_token_data&.[]("user_id")
    end

    # Fetch all projects for the authenticated user
    # @return [Array<Hash>] Array of project hashes with id and name
    def fetch_user_projects
      connection_params = {
        openstack_auth_url: auth_url,
        openstack_management_url: auth_url,
        openstack_auth_token: access_token,
      }
      identity = Fog::OpenStack::Identity.new(connection_params)
      identity.list_user_projects(user_id).body["projects"]
    end

    # Fetch all flavors across all projects for a user
    # @return [Array<Array>] Sorted array of [display_string, flavor_name, project_id]
    def fetch_all_flavors
      flavors = []

      fetch_user_projects.each do |project|
        scoped_token = scope_token_to_project(access_token, project['id'])

        compute_connection_params = {
          openstack_auth_url: auth_url,
          openstack_project_name: project['name'],
          openstack_management_url: "https://compute.#{openstack_instance}/v2.1/#{project['id']}",
          openstack_auth_token: scoped_token,
        }
        compute = Fog::OpenStack::Compute.new(compute_connection_params)

        compute.flavors.each do |flavor|
          flavors << [
            "#{flavor.name} - #{flavor.vcpus}VCPUS, #{flavor.ram/1024}GB RAM, #{flavor.disk}GB disk",
            flavor.name,
            project['id']
          ]
        end
      end

      flavors.sort
    end

    # Convenience method that returns both projects and flavors
    # @return [Array] Array containing [projects, flavors]
    def load_projects_and_flavors
      [fetch_user_projects, fetch_all_flavors]
    end

    # Scope token to a specific project
    # @param access_token [String] The unscoped token ID
    # @param project_id [String] The project ID to scope to
    # @return [String] The scoped token ID
    def scope_token_to_project(access_token, project_id)
      auth = {
        "auth": {
          "identity": {
            "methods": ["token"],
            "token": { "id": access_token }
          },
          "scope": { "project": { "id": project_id } }
        }
      }

      connection_params = {
        openstack_auth_url: auth_url,
        openstack_management_url: auth_url,
        openstack_auth_token: access_token,
      }
      identity = Fog::OpenStack::Identity.new(connection_params)
      identity.tokens.authenticate(auth)
    end
  end
end
