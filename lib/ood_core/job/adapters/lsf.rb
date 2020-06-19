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
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to LSF client executables
      # @option config [#to_s] :submit_host ('') Host to submit commands to
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
          info_ary = batch.get_job(id: id).map{|v| info_for_batch_hash(v)}
          handle_job_array(info_ary, id)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          batch.get_jobs.map { |v| info_for_batch_hash(v) }
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all of the owner's jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_where_owner
        def info_where_owner(owner, attrs: nil)
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
          info(id).status
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

        def directive_prefix
          '#BSUB'
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

            # Detect job array index from name
            array_index = /(\[\d+\])$/.match(v[:name])

            Info.new(
              id: (array_index) ? "#{v[:id]}#{array_index[1]}" : v[:id],
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

          def handle_job_array(info_ary, id)
            return Info.new(id: id, status: :completed) if info_ary.nil? || info_ary.empty?
            return info_ary.first if info_ary.size == 1

            parent_task_hash = build_proxy_parent(info_ary.first, id)

            info_ary.map do |task_info|
              parent_task_hash[:tasks] << {:id => task_info.id, :status => task_info.status}
            end

            parent_task_hash[:status] = parent_task_hash[:tasks].map{|task| task[:status]}.max

            Info.new(**parent_task_hash)
          end

          # Proxy the first element as the parent hash delete non-shared attributes
          def build_proxy_parent(info, id)
            info.to_h.merge({
              :tasks => [],
              :id => id
            }).delete_if{
              |key, _| [
                :allocated_nodes, :dispatch_time,
                :cpu_time, :wallclock_time, :status
              ].include?(key)
            }.tap{
              # Remove the child array index from the :job_name

              # Note that a true representation of the parent should have the
              # full array spec in the name. Worth attempting to reconstruct?
              |h| h[:job_name] = h[:job_name].gsub(/\[[^\]]+\]/, '')
            }
          end
      end
    end
  end
end
