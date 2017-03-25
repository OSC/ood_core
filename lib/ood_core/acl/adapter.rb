require "ood_support"

module OodCore
  module Acl
    # A class that handles the permissions for a resource through an ACL
    # @abstract
    class Adapter
      # Whether this ACL allows access for the principle
      # @abstract Subclass is expected to implement {#allow?}
      # @raise [NotImplementedError] if subclass did not define {#allow?}
      # @return [Boolean] whether principle is allowed
      def allow?
        raise NotImplementedError, "subclass did not define #allow?"
      end
    end
  end
end
