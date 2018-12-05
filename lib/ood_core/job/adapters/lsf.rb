require "ood_core/refinements/hash_extensions"
require "ood_core/job/adapters/helper"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Lsf adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [#to_s] :bindir ('') Path to lsf client bin dir
      # @option config [#to_s] :libdir ('') Path to lsf client lib dir
      # @option config [#to_s] :envdir ('') Path to lsf client conf dir
      # @option config [#to_s] :serverdir ('') Path to lsf client etc dir
      # @option config [#to_s] :cluster ('') name of cluster, if in multi-cluster mode
      # @option config [#to_h] :custom_bin ({}) Optional overrides to LSF client executables
      def self.build_lsf(config)
        batch = Adapters::Lsf::Batch.new(config.to_h.symbolize_keys)
        Adapters::Lsf.new(batch: batch)
      end
    end

    module Adapters
      class Lsf < Adapter
        using Refinements::ArrayExtensions

        # @api private
        attr_reader :batch, :helper

        require "ood_core/job/adapters/lsf/batch"
        require "ood_core/job/adapters/lsf/helper"

        STATE_MAP = {
          'RUN' => :running,
          'PEND' => :queued,
          'DONE' => :completed,
          'EXIT' => :completed,

          'PSUSP' => :queued_held, # supsended before job started, resumable via bresume
          'USUSP' => :suspended, # suspended after job started, resumable via bresume
          'SSUSP' => :suspended,

          'WAIT' => :queued, # FIXME: not sure what else to do here
          'ZOMBI' => :undetermined,
          'UNKWN' => :undetermined
        }

        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :batch The Lsf batch object
        #
        # @api private
        # @see Factory.build_lsf
        def initialize(batch:)
          @batch = batch
          @helper = Lsf::Helper.new
        end

        # Submit a job with the attributes defined in the job template instance
        # @param script [Script] script object that describes the script and
        #   attributes for the submitted job
        # @param after [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution at any point after dependent jobs have started execution
        # @param afterok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with no errors
        # @param afternotok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with errors
        # @param afterany [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution after dependent jobs have terminated
        # @raise [JobAdapterError] if something goes wrong submitting a job
        # @return [String] the job id returned after successfully submitting a
        #   job
        # @see Adapter#submit
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          # ensure dependencies are array of ids
          after      = Array(after).map(&:to_s)
          afterok    = Array(afterok).map(&:to_s)
          afternotok = Array(afternotok).map(&:to_s)
          afterany   = Array(afterany).map(&:to_s)

          kwargs = helper.batch_submit_args(script, after: after, afterok: afterok, afternotok: afternotok, afterany: afterany)

          batch.submit_string(script.content, **kwargs)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          # TODO: handle job arrays
          job = batch.get_job(id: id)
          if job
            info_for_batch_hash(job)
          else
            Info.new(
              id: id,
              status: :completed
            )
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all
          batch.get_jobs.map { |v| info_for_batch_hash(v) }
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all of the owner's jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_where_owner
        def info_where_owner(owner)
          owners = Array.wrap(owner).map(&:to_s)
          if owners.count > 1
            super
          elsif owners.count == 0
            []
          else
	    batch.get_jobs_for_user(owners.first).map { |v| info_for_batch_hash(v) }
	  end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          job = batch.get_job(id: id)
          state = job ? get_state(job[:status]) : :completed
          Status.new(state: state)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          batch.hold_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          batch.release_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          batch.delete_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        private
          # Determine state from LSF state code
          def get_state(st)
            STATE_MAP.fetch(st, :undetermined)
          end

          def info_for_batch_hash(v)
            nodes = helper.parse_exec_host(v[:exec_host]).map do |host|
              NodeInfo.new(name: host[:host], procs: host[:slots])
            end

            # FIXME: estimated_runtime should be set by batch object instead of
            dispatch_time = helper.parse_past_time(v[:start_time], ignore_errors: true)
            finish_time = helper.parse_past_time(v[:finish_time], ignore_errors: true)

            Info.new(
              id: v[:id],
              status: get_state(v[:status]),
              allocated_nodes: nodes,
              submit_host: v[:from_host],
              job_name: v[:name],
              job_owner: v[:user],
              accounting_id: v[:project],
              procs: nodes.any? ? nodes.map(&:procs).reduce(&:+) : 0,
              queue_name: v[:queue],
              wallclock_time: helper.estimate_runtime(current_time: Time.now, start_time: dispatch_time, finish_time: finish_time),
              cpu_time: helper.parse_cpu_used(v[:cpu_used]),
              # cpu_time: nil,
              submission_time: helper.parse_past_time(v[:submit_time], ignore_errors: true),
              dispatch_time: dispatch_time,
              native: v
            )
          end
      end
    end
  end
end
