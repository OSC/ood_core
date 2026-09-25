require "ood_core/job/adapters/coder/credentials"

# Credentials implementation for infrastructure that requires no cloud
# authentication, such as Docker or Kubernetes based Coder templates.
#
# The adapter always sends the application credential rich parameters when
# creating a workspace, and Coder rejects a build if a declared parameter is
# not supplied, so empty values are returned rather than omitting them.
class NoneCredentials < CredentialsInterface

  def initialize(**kwargs) end

  def generate_credentials(project_id = nil)
    { id: "", name: "", secret: "", user_id: "" }
  end

  def save_credentials(id, app_credentials)
    # nothing to persist
  end

  def load_credentials(id)
    {}
  end

  def destroy_credentials(app_credentials, deletion_status, id)
    # nothing to revoke
  end
end
