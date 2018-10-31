require "ood_core/refinements/array_extensions"
require "ood_core/refinements/hash_extensions"

# TODO edit comments calling out slurm stuff

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Sun Grid Engine adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :cluster (nil) The cluster to communicate with
      # @option config [Object] :conf (nil) Path to the SGE conf
      # @option config [Object] :bin (nil) Path to SGE client binaries
      def self.build_sge(config)
        # c = config.to_h.symbolize_keys
        # cluster = c.fetch(:cluster, nil)
        # conf    = c.fetch(:conf, nil)
        # bin     = c.fetch(:bin, nil)
        # Adapters::Sge.new(cluster: cluster, conf: conf, bin: bin)
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
        # @example CHPC's kingspeak cluster
        #   my_batch.cluster #=> "kingspeak"
        # @return [String, nil] the cluster name
        attr_reader :cluster

        # The path to the Sun Grid Engine configuration file
        # @example For Sun Grid Engine 10.0.0
        #   my_batch.conf.to_s #=> "/etc/gridengine/configuration
        # @return [Pathname, nil] path to gridengine conf
        attr_reader :conf

        # The path to the Sun Grid Engine client installation binaries
        # @example For Sun Grid Engine 10.0.0
        #   my_batch.bin.to_s #=> "/usr/local/slurm/10.0.0/bin
        # @return [Pathname] path to slurm binaries
        attr_reader :bin

        # The root exception class that all Sun Grid Engine-specific exceptions inherit
        # from
        class Error < StandardError; end

        # @param cluster [#to_s, nil] the cluster name
        # @param conf [#to_s, nil] path to the slurm conf
        # @param bin [#to_s] path to slurm installation binaries
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
        def info_all
          @batch.get_all
        rescue Batch::Error => e
            raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner)
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
          job_info = @batch.get_info_historical_job(id.to_s)
          return job_info unless job_info.nil?

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
      end
    end
  end
end