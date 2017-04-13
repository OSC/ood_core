require "ood_core/refinements/hash_extensions"

module OodCore
  module Acl
    class Factory
      using Refinements::HashExtensions

      # Build the group acl adapter from a configuration
      # @param config [#to_h] the configuration for an acl adapter
      # @option config [Array<#to_s>] :groups The list of groups
      # @option config [#to_s] :type ('whitelist') The type of ACL ('whitelist' or 'blacklist')
      def self.build_group(config)
        c = config.to_h.symbolize_keys

        groups = c.fetch(:groups) { raise ArgumentError, "No groups specified. Missing argument: groups" }.map(&:to_s)
        acl = OodSupport::ACL.new(entries: groups.map { |g| OodSupport::ACLEntry.new principle: g })

        type   = c.fetch(:type, "whitelist").to_s
        if type == "whitelist"
          allow = true
        elsif type == "blacklist"
          allow = false
        else
          raise ArgumentError, "Invalid type specified. Valid types: whitelist, blacklist"
        end

        Adapters::Group.new(acl: acl, allow: allow)
      end
    end

    module Adapters
      # An adapter object that describes a group permission ACL
      class Group < Adapter
        using Refinements::HashExtensions

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [OodSupport::ACL] :acl The ACL permission
        # @option opts [Boolean] :allow (true) Whether this ACL allows access
        # @see Factory.build_group
        def initialize(opts)
          o = opts.to_h.symbolize_keys
          @acl = o.fetch(:acl) { raise ArgumentError, "No acl specified. Missing argument: acl" }
          @allow = o.fetch(:allow, true)
        end

        # Whether this ACL allows the active user access based on their groups
        # @return [Boolean] whether principle is allowed
        def allow?
          if @allow
            OodSupport::User.new.groups.map(&:to_s).any? { |g| @acl.allow?(principle: g) }
          else
            OodSupport::User.new.groups.map(&:to_s).none? { |g| @acl.allow?(principle: g) }
          end
        end
      end
    end
  end
end
