require "ood_core/refinements/array_extensions"
require "ood_core/refinements/hash_extensions"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Sun Grid Engine adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :cluster (nil) The cluster to communicate with
      # @option config [Object] :conf (nil) Path to the SGE conf
      # @option config [Object] :bin (nil) Path to SGE client binaries
      # @option config [Object] :sge_root (nil) Path to SGE root, note that
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to SGE client executables
      #   this may be nil, but must be set to use the DRMAA API, and there is a
      #   severe performance penalty calling Sge#info without using DRMAA.
      def self.build_sge(config)
        batch = Adapters::Sge::Batch.new(config.to_h.symbolize_keys)
        Adapters::Sge.new(batch: batch)
      end
    end

    module Adapters
      class Sge < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions

        require "ood_core/job/adapters/sge/batch"
        require "ood_core/job/adapters/sge/helper"

        # The cluster of the Sun Grid Engine batch server
        # @example UCLA's hoffman2 cluster
        #   my_batch.cluster #=> "hoffman2"
        # @return [String, nil] the cluster name
        attr_reader :cluster

        # The path to the Sun Grid Engine configuration file
        # @example For Sun Grid Engine 8.0.1
        #   my_batch.conf.to_s #=> "/u/systems/UGE8.0.1vm/h2.conf
        # @return [Pathname, nil] path to gridengine conf
        attr_reader :conf

        # The path to the Sun Grid Engine client installation binaries
        # @example For Sun Grid Engine 8.0.1
        #   my_batch.bin.to_s #=> "/u/systems/UGE8.0.1vm/bin/lx-amd64/
        # @return [Pathname] path to SGE binaries
        attr_reader :bin

        # The root exception class that all Sun Grid Engine-specific exceptions inherit
        # from
        class Error < StandardError; end

        # @param batch [Adapters::Sge::Batch]
        def initialize(batch:)
          @batch = batch
          @helper = Sge::Helper.new
        end

        # Submit a job with the attributes defined in the job template instance
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
        # @raise [JobAdapterError] if something goes wrong submitting a job
        # @return [String] the job id returned after successfully submitting a job
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          # SGE supports jod dependencies on job completion
          args = @helper.batch_submit_args(script, after: after, afterok: afterok, afternotok: afternotok, afterany: afterany)

          @batch.submit(script.content, args)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @return [Array<Info>] information describing submitted jobs
        def info_all(attrs: nil)
          @batch.get_all(owner: '*')
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner, attrs: nil)
          owner = Array.wrap(owner).map(&:to_s).join(',')
          @batch.get_all(owner: owner)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        def info(id)
          @batch.get_info_enqueued_job(id)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting the status of a job
        # @return [Status] status of job
        def status(id)
          info(id).status
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        def hold(id)
          @batch.hold(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        def release(id)
          @batch.release(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        def delete(id)
          @batch.delete(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        def directive_prefix
          '#$'
        end
      end
    end
  end
end
