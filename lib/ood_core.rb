require "ood_core/version"
require "ood_core/errors"
require "ood_core/cluster"
require "ood_core/clusters"

# The main namespace for ood_core
module OodCore
  # A namespace for job access
  module Job
    require "ood_core/job/node_info"
    require "ood_core/job/node_request"
    require "ood_core/job/script"
    require "ood_core/job/info"
    require "ood_core/job/status"
    require "ood_core/job/adapter"
    require "ood_core/job/factory"

    # A namespace for job adapters
    # @note These are dynamically loaded upon request
    module Adapters
    end
  end

  # A namespace for acl code
  module Acl
    require "ood_core/acl/adapter"
    require "ood_core/acl/factory"

    # A namespace for acl adapters
    # @note These are dynamically loaded upon request
    module Adapters
    end
  end
end
