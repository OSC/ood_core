require "ood_core/refinements/hash_extensions"

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
      def self.build_lsf(config)
        batch = Adapters::Lsf::Batch.new(config.to_h.symbolize_keys)
        Adapters::Lsf.new(batch: batch)
      end
    end

    module Adapters
      class Lsf < Adapter
        attr_reader :batch

        require "ood_core/job/adapters/lsf/batch"

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
        def initialize(batch:)
          @batch = batch
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

          args = []
          args += ["-P", script.accounting_id] unless script.accounting_id.nil?
          args += ["-cwd", script.workdir.to_s] unless script.workdir.nil?
          args += ["-J", script.job_name] unless script.job_name.nil?

          # TODO: dependencies

          env = {
            #TODO:
            #LSB_HOSTS?
            #LSB_MCPU_HOSTS?
            #SNDJOBS_TO?
            #
          }

          # Submit job
          batch.submit_string(script.content, args: args, env: env)

        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          info_shared(id: id)
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all
          info_shared
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          # TODO: Optimize slightly over retrieving complete job information from server
          id = id.to_s
          if job = batch.get_jobs(id: id).detect { |j| j[:id] }
            Status.new(state: get_state(job[:status]))
          else
            Status.new(state: :completed)
          end
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

          # Retrieve job info from the resource manager
          # @param id [#to_s] the id of the job, otherwise get list of all jobs
          # @return [Info, Array<Info>] information describing submitted job
          def info_shared(id: '')
            # TODO: refactor away
            id = id.to_s

            info_ary = batch.get_jobs(id: id).map { |v|
              Info.new(
                id: v[:id],
                status: get_state(v[:status]),
                allocated_nodes: [],
                submit_host: v[:from_host],
                job_name: v[:name],
                job_owner: v[:user],
                accounting_id: v[:project],
                procs: nil,
                queue_name: v[:queue],
                wallclock_time: nil,
                cpu_time: nil,
                submission_time: nil,
                dispatch_time: nil,
                native: v
              )
            }

            if id.empty?
              info_ary
            else
              # TODO: handle job arrays
              info_ary.first
            end
          rescue Batch::Error => e
            raise JobAdapterError, e.message
          end
      end
    end
  end
end
