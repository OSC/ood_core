require "ood_core/refinements/hash_extensions"

gem "pbs", "~> 2.0"
require "pbs"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Torque adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [#to_s] :host The batch server host
      # @option config [#to_s] :lib ('') Path to torque client libraries
      # @option config [#to_s] :bin ('') Path to torque client binaries
      def self.build_torque(config)
        c = config.to_h.symbolize_keys
        host = c.fetch(:host) { raise ArgumentError, "No host specified. Missing argument: host" }.to_s
        lib  = c.fetch(:lib, "").to_s
        bin  = c.fetch(:bin, "").to_s
        pbs  = PBS::Batch.new(host: host, lib: lib, bin: bin)
        Adapters::Torque.new(pbs: pbs)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Torque resource
      # manager for job management.
      class Torque < Adapter
        using Refinements::HashExtensions

        # Mapping of state characters for PBS
        STATE_MAP = {
          'Q' => :queued,
          'H' => :queued_held,
          'T' => :queued_held,    # transiting, most like a held job
          'R' => :running,
          'S' => :suspended,
          'E' => :running,        # exiting, but still running
          'C' => :completed
        }

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [PBS::Batch] :pbs The PBS batch object
        # @see Factory.build_torque
        def initialize(opts = {})
          o = opts.to_h.symbolize_keys

          @pbs = o.fetch(:pbs) { raise ArgumentError, "No pbs object specified. Missing argument: pbs" }
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
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          after      = Array(after).map(&:to_s)
          afterok    = Array(afterok).map(&:to_s)
          afternotok = Array(afternotok).map(&:to_s)
          afterany   = Array(afterany).map(&:to_s)

          # Set headers
          headers = {}
          headers.merge!(job_arguments: script.args.join(' ')) unless script.args.nil?
          headers.merge!(Hold_Types: :u) if script.submit_as_hold
          headers.merge!(Rerunable: script.rerunnable ? 'y' : 'n') unless script.rerunnable.nil?
          headers.merge!(init_work_dir: script.workdir) unless script.workdir.nil?
          headers.merge!(Mail_Users: script.email.join(',')) unless script.email.nil?
          mail_points  = ''
          mail_points += 'b' if script.email_on_started
          mail_points += 'e' if script.email_on_terminated
          headers.merge!(Mail_Points: mail_points) unless mail_points.empty?
          headers.merge!(Job_Name: script.job_name) unless script.job_name.nil?
          # ignore input_path (not defined in Torque)
          headers.merge!(Output_Path: script.output_path) unless script.output_path.nil?
          headers.merge!(Error_Path: script.error_path) unless script.error_path.nil?
          # If error_path is not specified we join stdout & stderr (as this
          # mimics what the other resource managers do)
          headers.merge!(Join_Path: 'oe') if script.error_path.nil?
          headers.merge!(reservation_id: script.reservation_id) unless script.reservation_id.nil?
          headers.merge!(Priority: script.priority) unless script.priority.nil?
          headers.merge!(Execution_Time: script.start_time.localtime.strftime("%C%y%m%d%H%M.%S")) unless script.start_time.nil?
          headers.merge!(Account_Name: script.accounting_id) unless script.accounting_id.nil?

          # Set dependencies
          depend = []
          depend << "after:#{after.join(':')}"           unless after.empty?
          depend << "afterok:#{afterok.join(':')}"       unless afterok.empty?
          depend << "afternotok:#{afternotok.join(':')}" unless afternotok.empty?
          depend << "afterany:#{afterany.join(':')}"     unless afterany.empty?
          headers.merge!(depend: depend.join(','))       unless depend.empty?

          # Set resources
          resources = {}
          resources.merge!(mem: "#{script.min_phys_memory}KB") unless script.min_phys_memory.nil?
          resources.merge!(walltime: seconds_to_duration(script.wall_time)) unless script.wall_time.nil?

          # Set environment variables
          envvars = script.job_environment || {}

          # Set native options
          if script.native
            headers.merge!   script.native.fetch(:headers, {})
            resources.merge! script.native.fetch(:resources, {})
            envvars.merge!   script.native.fetch(:envvars, {})
          end

          # Submit job
          @pbs.submit_string(script.content, queue: script.queue_name, headers: headers, resources: resources, envvars: envvars)
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all
          @pbs.get_jobs.map do |k, v|
            parse_job_info(k, v)
          end
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          id = id.to_s
          parse_job_info(*@pbs.get_job(id).flatten)
        rescue PBS::UnkjobidError
          # set completed status if can't find job id
          Info.new(
            id: id,
            status: :completed
          )
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          id = id.to_s
          char = @pbs.get_job(id, filters: [:job_state])[id][:job_state]
          Status.new(state: STATE_MAP.fetch(char, :undetermined))
        rescue PBS::UnkjobidError
          # set completed status if can't find job id
          Status.new(state: :completed)
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          @pbs.hold_job(id.to_s)
        rescue PBS::UnkjobidError
          # assume successful job hold if can't find job id
          nil
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          @pbs.release_job(id.to_s)
        rescue PBS::UnkjobidError
          # assume successful job release if can't find job id
          nil
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          @pbs.delete_job(id.to_s)
        rescue PBS::UnkjobidError, PBS::BadstateError
          # assume successful job deletion if can't find job id
          # assume successful job deletion if job is exiting or completed
          nil
        rescue PBS::Error => e
          raise JobAdapterError, e.message
        end

        private
          # Convert duration to seconds
          def duration_in_seconds(time)
            time.nil? ? 0 : time.split(':').map { |v| v.to_i }.inject(0) { |total, v| total * 60 + v }
          end

          # Convert seconds to duration
          def seconds_to_duration(time)
            '%02d:%02d:%02d' % [time/3600, time/60%60, time%60]
          end

          # Convert host list string to individual nodes
          # "n0163/2,7,10-11+n0205/0-11+n0156/0-11"
          def parse_nodes(node_list)
            node_list.split('+').map do |n|
              name, procs_list = n.split('/')
              # count procs used in range expression
              procs = procs_list.split(',').inject(0) do |sum, x|
                sum + (x =~ /^(\d+)-(\d+)$/ ? ($2.to_i - $1.to_i) : 0) + 1
              end
              {name: name, procs: procs}
            end
          end

          # Parse hash describing PBS job status
          def parse_job_info(k, v)
            /^(?<job_owner>[\w-]+)@/ =~ v[:Job_Owner]
            allocated_nodes = parse_nodes(v[:exec_host] || "")
            Info.new(
              id: k,
              status: STATE_MAP.fetch(v[:job_state], :undetermined),
              allocated_nodes: allocated_nodes,
              submit_host: v[:submit_host],
              job_name: v[:Job_Name],
              job_owner: job_owner,
              accounting_id: v[:Account_Name],
              procs: allocated_nodes.inject(0) { |sum, x| sum + x[:procs] },
              queue_name: v[:queue],
              wallclock_time: duration_in_seconds(v.fetch(:resources_used, {})[:walltime]),
              cpu_time: duration_in_seconds(v.fetch(:resources_used, {})[:cput]),
              submission_time: v[:ctime],
              dispatch_time: v[:start_time],
              native: v
            )
          end
      end
    end
  end
end
