require "ood_support"

module OodCore
  module AclAdapters
    # A class that handles whether a resource is allowed to be used through an
    # ACL
    # @abstract
    class AbstractAdapter
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
