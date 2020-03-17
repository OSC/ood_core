require "ood_core/version"
require "ood_core/errors"
require "ood_core/cluster"
require "ood_core/clusters"
require "ood_core/invalid_cluster"

# The main namespace for ood_core
module OodCore
  # A namespace for job access
  module Job
    require "ood_core/job/node_info"
    require "ood_core/job/script"
    require "ood_core/job/info"
    require "ood_core/job/status"
    require "ood_core/job/adapter"
    require "ood_core/job/factory"
    require "ood_core/job/task"

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

  # A namespace for batch connect code
  module BatchConnect
    require "ood_core/batch_connect/template"
    require "ood_core/batch_connect/factory"
  end
end
