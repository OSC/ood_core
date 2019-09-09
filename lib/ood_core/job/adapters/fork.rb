require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"
require "set"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Fork adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :hosts (nil) The list of permissable hosts
      def self.build_fork(config)
        c = config.to_h.symbolize_keys
        ssh_hosts = c.fetch(:ssh_hosts, [])
        max_timeout = c.fetch(:max_timeout, nil)
        tmux_bin = c.fetch(:tmux_bin, '/usr/bin/tmux')

        Adapters::Fork.new(
          ssh_hosts: ssh_hosts,
          forker: Adapters::Fork::Forker.new(tmux_bin: tmux_bin, max_timeout: max_timeout, ssh_hosts: ssh_hosts)
        )
      end
    end

    module Adapters
      # An adapter object that describes the communication with a remote host
      # for job management.
      class Fork < Adapter
        using Refinements::ArrayExtensions

        require "ood_core/job/adapters/fork/forker"

        def initialize(ssh_hosts:, forker:)
          @forker = forker
          @ssh_hosts = Set.new(ssh_hosts)
        end

        # Submit a job with the attributes defined in the job template instance
        # @abstract Subclass is expected to implement {#submit}
        # @raise [NotImplementedError] if subclass did not define {#submit}
        # @example Submit job template to cluster
        #   solver_id = job_adapter.submit(solver_script)
        #   #=> "1234.server"
        # @example Submit job that depends on previous job
        #   post_id = job_adapter.submit(
        #     post_script,
        #     afterok: solver_id
        #   )
        #   #=> "1235.server"
        # @param script [Script] script object that describes the
        #   script and attributes for the submitted job
        # @param after [#to_s, Array<#to_s>] this job may be scheduled for execution
        #   at any point after dependent jobs have started execution
        # @param afterok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with no errors
        # @param afternotok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with errors
        # @param afterany [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution after dependent jobs have terminated
        # @return [String] the job id returned after successfully submitting a job
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          host_permitted?(script.native['destination_host'])
          
          @forker.start_remote_tmux_session(script)
        end

        # Retrieve info for all jobs from the resource manager
        # @abstract Subclass is expected to implement {#info_all}
        # @raise [NotImplementedError] if subclass did not define {#info_all}
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @return [Array<Info>] information describing submitted jobs
        def info_all(attrs: nil, host: nil)
          @forker.list_remote_tmux_sessions(host: host).map{
            |ls_output| ls_to_info(ls_output)
          }
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner: nil, attrs: nil)
          info_all
        end

        # Iterate over each job Info object
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_all_each(attrs: nil)
          return to_enum(:info_all_each, attrs: attrs) unless block_given?

          info_all(attrs: attrs).each do |job|
            yield job
          end
        end

        # Iterate over each job Info object
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_where_owner_each(owner, attrs: nil)
          return to_enum(:info_where_owner_each, owner, attrs: attrs) unless block_given?

          info_where_owner(owner, attrs: attrs).each do |job|
            yield job
          end
        end

        # Whether the adapter supports job arrays
        # @return [Boolean] - assumes true; but can be overridden by adapters that
        #   explicitly do not
        def supports_job_arrays?
          false
        end

        # Retrieve job info from the resource manager
        # @abstract Subclass is expected to implement {#info}
        # @raise [NotImplementedError] if subclass did not define {#info}
        # @param id [#to_s] the id of the job
        # @return [Info] information describing submitted job
        def info(id)
          _, host = *(id.split('@'))
          job = info_all(host: host).select{|info| info.id == id}.first
          (job) ? job : Info.new(id: id, status: :completed)
        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id)
          if info_all.select{|info| info.id == id}.count == 1
            :running
          else
            :completed
          end
        end

        # Put the submitted job on hold
        # @abstract Subclass is expected to implement {#hold}
        # @raise [NotImplementedError] if subclass did not define {#hold}
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id)
          # Consider sending SIGSTOP?
          raise NotImplementedError, "subclass did not define #hold"
        end

        # Release the job that is on hold
        # @abstract Subclass is expected to implement {#release}
        # @raise [NotImplementedError] if subclass did not define {#release}
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id)
          # Consider ssh HOST fg job ID?
          raise NotImplementedError, "subclass did not define #release"
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          session_name, destination_host = *id.split('@')
          host_permitted?(destination_host)
          @forker.stop_remote_tmux_session(session_name: session_name, hostname: destination_host)
        end

        private

        def host_permitted?(destination_host)
          raise JobAdapterError, "Requested destination host (#{destination_host}) not permitted" unless @ssh_hosts.include?(destination_host)
        end

        # Convert the returned Hash into an Info object
        # TODO: walltime, submit time, allocated nodes, native...these are all definable, there may be others
        def ls_to_info(ls_output)
            Info.new(
                id: ls_output[:id],
                status: :running,
            )
        end
      end
    end
  end
end
