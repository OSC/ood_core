module OodCore
  # A special case of an OodCore::Cluster where something went awry in the
  # creation and it's invalid for some reason.  Users should only be able
  # to rely on id and metadata.error_msg. All *allow? related functions
  # false, meaning nothing is allowed.
  class InvalidCluster < Cluster
    # Jobs are not allowed
    # @return false
    def login_allow?
      false
    end

    # Jobs are not allowed
    # @return false
    def job_allow?
      false
    end

    # Custom features are not allowed
    # @return false
    def custom_allow?(_)
      false
    end

    # This cluster is not allowed to be used
    # @return false
    def allow?
      false
    end

    # This cluster is never valid
    # @return false
    def valid?
      return false
    end
  end
end
