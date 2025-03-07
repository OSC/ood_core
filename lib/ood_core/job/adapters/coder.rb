require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require 'net/http'
require 'json'
require 'etc'

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      def self.build_coder(config)
        batch = Adapters::Coder::Batch.new(config.to_h.symbolize_keys)
        Adapters::Coder.new(batch)
      end
    end

    module Adapters
      attr_reader :host, :token

      # The adapter class for Kubernetes.
      class Coder < Adapter

        using Refinements::ArrayExtensions
        using Refinements::HashExtensions

        require "ood_core/job/adapters/coder/batch"

        attr_reader :batch
        def initialize(batch)
          @batch = batch
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
        # @return [String] the job id returned after successfully submitting a job
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          raise ArgumentError, 'Must specify the script' if script.nil?
          batch.submit(script)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
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
        def info_all(attrs: nil)
        # TODO - implement info all for namespaces?
          batch.method_missing(attrs: attrs)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
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
          batch.info(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id)
          info(id)["job"]["status"]
        end

        # Delete the submitted job.
        #
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          res = batch.delete(id)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end
      end
    end
  end
end