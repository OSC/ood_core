require "ood_core/refinements/hash_extensions"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Lsf adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [#to_s] :host The batch server host
      # @option config [#to_s] :lib ('') Path to lsf client libraries
      # @option config [#to_s] :bin ('') Path to lsf client binaries
      def self.build_lsf(config)
        c = config.to_h.symbolize_keys
        batch = Adapters::Lsf::Batch.new(bin: c.fetch(:bin, ""))
        Adapters::Lsf.new(batch: batch)
      end
    end

    module Adapters
      class Lsf < Adapter
        attr_reader :batch

        require "ood_core/job/adapters/lsf/batch"

        STATE_MAP = {
           #TODO: map LSF states to queued, queued_held, running, etc.
        }

        # @param opts [#to_h] the options defining this adapter
        # @option config [#to_s] :host The batch server host
        # @option config [#to_s] :lib ('') Path to lsf client libraries
        # @option config [#to_s] :bin ('') Path to lsf client binaries
        def initialize(batch:)
          @batch = batch
        end

        # Submit a job with the attributes defined in the job template instance
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
        # @raise [JobAdapterError] if something goes wrong submitting a job
        # @return [String] the job id returned after successfully submitting a job
        # @see Adapter#submit
        def submit(script:, after: [], afterok: [], afternotok: [], afterany: [])
          # ensure dependencies are array of ids
          after      = Array(after).map(&:to_s)
          afterok    = Array(afterok).map(&:to_s)
          afternotok = Array(afternotok).map(&:to_s)
          afterany   = Array(afterany).map(&:to_s)

          args = []
          args += ["-P", script.accounting_id] unless script.accounting_id.nil?

          # TODO: dependencies

          env = {
            #TODO:
            #LSB_HOSTS?
            #LSB_MCPU_HOSTS?
            #SNDJOBS_TO?
            #
          }

          # Submit job
          @batch.submit_string(script.content, args: args, env: env)

          #TODO: rescue Batch::Error
        end

        # Retrieve job info from the resource manager
        # @abstract Subclass is expected to implement {#info}
        # @raise [NotImplementedError] if subclass did not define {#info}
        # @param id [#to_s] the id of the job, otherwise get list of all jobs
        #   running on cluster
        # @return [Info, Array<Info>] information describing submitted job
        def info(id: '')
          id = id.to_s

          raise NotImplementedError, "subclass did not define #info"
        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #status"
        end

        # Put the submitted job on hold
        # @abstract Subclass is expected to implement {#hold}
        # @raise [NotImplementedError] if subclass did not define {#hold}
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #hold"
        end

        # Release the job that is on hold
        # @abstract Subclass is expected to implement {#release}
        # @raise [NotImplementedError] if subclass did not define {#release}
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #release"
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id:)
          id = id.to_s

          raise NotImplementedError, "subclass did not define #delete"
        end
      end
    end
  end
end
