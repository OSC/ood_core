require "ood_core/refinements/hash_extensions"
require "ood_core/job/adapters/helper"
require 'shellwords'

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Torque adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [#to_s] :host The batch server host
      # @option config [#to_s] :submit_host The login node to submit the job via ssh
      # @option config [#to_s] :lib ('') Path to torque client libraries
      # @option config [#to_s] :bin ('') Path to torque client binaries
      # @option config [#to_h] :custom_bin ({}) Optional overrides to Torque client executables
      def self.build_torque(config)
        c = config.to_h.symbolize_keys
        host = c.fetch(:host) { raise ArgumentError, "No host specified. Missing argument: host" }.to_s
        submit_host = c.fetch(:submit_host, "").to_s
        lib  = c.fetch(:lib, "").to_s
        bin  = c.fetch(:bin, "").to_s
        custom_bin = c.fetch(:custom_bin, {})
        pbs  = Adapters::Torque::Batch.new(host: host, submit_host: submit_host, lib: lib, bin: bin, custom_bin: custom_bin)
        Adapters::Torque.new(pbs: pbs)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Torque resource
      # manager for job management.
      class Torque < Adapter
        using Refinements::ArrayExtensions
        using Refinements::HashExtensions

        require "ood_core/job/adapters/torque/error"
        require "ood_core/job/adapters/torque/attributes"
        require "ood_core/job/adapters/torque/ffi"
        require "ood_core/job/adapters/torque/batch"

        # Mapping of state characters for PBS
        STATE_MAP = {
          'Q' => :queued,
          'H' => :queued_held,
          'T' => :queued_held,    # transiting (being moved to new location)
          'W' => :queued_held,    # waiting (waiting for its execution time)
          'R' => :running,
          'S' => :suspended,
          'E' => :running,        # exiting, but still running
          'C' => :completed
        }

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [Torque::Batch] :pbs The PBS batch object
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

          # Set dependencies
          depend = []
          depend << "after:#{after.join(':')}"           unless after.empty?
          depend << "afterok:#{afterok.join(':')}"       unless afterok.empty?
          depend << "afternotok:#{afternotok.join(':')}" unless afternotok.empty?
          depend << "afterany:#{afterany.join(':')}"     unless afterany.empty?

          # Set mailing options
          mail_points = ""
          mail_points += "b" if script.email_on_started
          mail_points += "e" if script.email_on_terminated

          # FIXME: Remove the Hash option once all Interactive Apps are
          # converted to Array format
          if script.native.is_a?(Hash)
            # Set headers
            headers = {}
            headers.merge!(job_arguments: script.args.join(' ')) unless script.args.nil?
            headers.merge!(Hold_Types: :u) if script.submit_as_hold
            headers.merge!(Rerunable: script.rerunnable ? 'y' : 'n') unless script.rerunnable.nil?
            headers.merge!(init_work_dir: script.workdir) unless script.workdir.nil?
            headers.merge!(Mail_Users: script.email.join(',')) unless script.email.nil?
            headers.merge!(Mail_Points: mail_points) unless mail_points.empty?
            headers.merge!(Job_Name: script.job_name) unless script.job_name.nil?
            headers.merge!(Shell_Path_List: script.shell_path) unless script.shell_path.nil?
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
            headers.merge!(depend: depend.join(','))       unless depend.empty?
            headers.merge!(job_array_request: script.job_array_request) unless script.job_array_request.nil?

            # Set resources
            resources = {}
            resources.merge!(walltime: seconds_to_duration(script.wall_time)) unless script.wall_time.nil?

            # Set environment variables
            envvars = script.job_environment || {}

            # Set native options
            if script.native
              headers.merge!   script.native.fetch(:headers, {})
              resources.merge! script.native.fetch(:resources, {})
              envvars.merge!   script.native.fetch(:envvars, {})
            end

            # Destructively change envvars to shellescape values
            envvars.transform_values! { |v| Shellwords.escape(v) }

            # Submit job
            @pbs.submit_string(script.content, queue: script.queue_name, headers: headers, resources: resources, envvars: envvars)
          else
            # Set qsub arguments
            args = []
            args.concat ["-F", script.args.join(" ")] unless script.args.nil?
            args.concat ["-h"] if script.submit_as_hold
            args.concat ["-r", script.rerunnable ? "y" : "n"] unless script.rerunnable.nil?
            args.concat ["-M", script.email.join(",")] unless script.email.nil?
            args.concat ["-m", mail_points] unless mail_points.empty?
            args.concat ["-N", script.job_name] unless script.job_name.nil?
            args.concat ["-S", script.shell_path] unless script.shell_path.nil?
            # ignore input_path (not defined in Torque)
            args.concat ["-o", script.output_path] unless script.output_path.nil?
            args.concat ["-e", script.error_path] unless script.error_path.nil?
            args.concat ["-W", "x=advres:#{script.reservation_id}"] unless script.reservation_id.nil?
            args.concat ["-q", script.queue_name] unless script.queue_name.nil?
            args.concat ["-p", script.priority] unless script.priority.nil?
            args.concat ["-a", script.start_time.localtime.strftime("%C%y%m%d%H%M.%S")] unless script.start_time.nil?
            args.concat ["-A", script.accounting_id] unless script.accounting_id.nil?
            args.concat ["-W", "depend=#{depend.join(",")}"] unless depend.empty?
            args.concat ["-l", "walltime=#{seconds_to_duration(script.wall_time)}"] unless script.wall_time.nil?
            args.concat ['-t', script.job_array_request] unless script.job_array_request.nil?
            args.concat ['-l', "qos=#{script.qos}"] unless script.qos.nil?
            args.concat ['-l', "gpus=#{script.gpus_per_node}"] unless script.gpus_per_node.nil?

            # Set environment variables
            env = script.job_environment.to_h
            args.concat ["-v", env.keys.join(",")] unless env.empty?
            args.concat ["-V"] if script.copy_environment?

            # If error_path is not specified we join stdout & stderr (as this
            # mimics what the other resource managers do)
            args.concat ["-j", "oe"] if script.error_path.nil?

            # Set native options
            args.concat script.native if script.native

            # Submit job
            @pbs.submit(script.content, args: args, env: env, chdir: script.workdir)
          end
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          @pbs.get_jobs.map do |k, v|
            parse_job_info(k, v)
          end
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner, attrs: nil)
          owner = Array.wrap(owner).map(&:to_s)
          @pbs.select_jobs(
            attribs: [
              { name: "User_List", value: owner.join(","), op: :eq }
            ]
          ).map do |k, v|
            parse_job_info(k, v)
          end
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          id = id.to_s
          result = @pbs.get_job(id)

          if result.keys.length == 1
            parse_job_info(*result.flatten)
          else
            parse_job_array(id, result)
          end
        rescue Torque::FFI::UnkjobidError
          # set completed status if can't find job id
          Info.new(
            id: id,
            status: :completed
          )
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          id = id.to_s
          @pbs.get_job(id, filters: [:job_state]).values.map {
            |job_status| OodCore::Job::Status.new(
              state: STATE_MAP.fetch(
                job_status[:job_state], :undetermined
              )
            )
          }.max
        rescue Torque::FFI::UnkjobidError
          # set completed status if can't find job id
          Status.new(state: :completed)
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          @pbs.hold_job(id.to_s)
        rescue Torque::FFI::UnkjobidError
          # assume successful job hold if can't find job id
          nil
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          @pbs.release_job(id.to_s)
        rescue Torque::FFI::UnkjobidError
          # assume successful job release if can't find job id
          nil
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          @pbs.delete_job(id.to_s)
        rescue Torque::FFI::UnkjobidError, Torque::FFI::BadstateError
          # assume successful job deletion if can't find job id
          # assume successful job deletion if job is exiting or completed
          nil
        rescue Torque::Batch::Error => e
          raise JobAdapterError, e.message
        end

        def directive_prefix
          '#QSUB'
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

          def parse_job_array(parent_id, result)
            results = result.to_a

            parse_job_info(
              parent_id,
              results.first.last.tap { |info_hash| info_hash[:exec_host] = aggregate_exec_host(results) },
              tasks: generate_task_list(results)
            )
          end

          def aggregate_exec_host(results)
            results.map { |k,v| v[:exec_host] }.compact.sort.uniq.join("+")
          end

          def generate_task_list(results)
            results.map do |k, v|
              {
                :id => k,
                :status => STATE_MAP.fetch(v[:job_state], :undetermined)
              }
            end
          end

          # Parse hash describing PBS job status
          def parse_job_info(k, v, tasks: [])
            /^(?<job_owner>[\w-]+)@/ =~ v[:Job_Owner]
            allocated_nodes = parse_nodes(v[:exec_host] || "")
            procs = allocated_nodes.inject(0) { |sum, x| sum + x[:procs] }
            if allocated_nodes.empty?
              allocated_nodes = [ { name: nil } ] * v.fetch(:Resource_List, {})[:nodect].to_i
              # Only cover the simplest of cases where there is a single
              # `ppn=##` and ignore otherwise
              ppn_list = v.fetch(:Resource_List, {})[:nodes].to_s.scan(/ppn=(\d+)/)
              if ppn_list.size == 1
                procs = allocated_nodes.size * ppn_list.first.first.to_i
              end
            end
            Info.new(
              id: k,
              status: STATE_MAP.fetch(v[:job_state], :undetermined),
              allocated_nodes: allocated_nodes,
              submit_host: v[:submit_host],
              job_name: v[:Job_Name],
              job_owner: job_owner,
              accounting_id: v[:Account_Name],
              procs: procs,
              queue_name: v[:queue],
              wallclock_time: duration_in_seconds(v.fetch(:resources_used, {})[:walltime]),
              wallclock_limit: duration_in_seconds(v.fetch(:Resource_List, {})[:walltime]),
              cpu_time: duration_in_seconds(v.fetch(:resources_used, {})[:cput]),
              submission_time: v[:ctime],
              dispatch_time: v[:start_time],
              native: v,
              tasks: tasks
            )
          end
      end
    end
  end
end
