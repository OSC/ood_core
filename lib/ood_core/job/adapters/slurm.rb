require "time"
require "ood_core/refinements/hash_extensions"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Slurm adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [#to_s] :host The cluster to communicate with
      # @option config [#to_s] :bin ('') Path to slurm client binaries
      def self.build_slurm(config)
        c = config.to_h.symbolize_keys
        cluster = c.fetch(:cluster) { raise ArgumentError, "No cluster specified. Missing argument: cluster" }.to_s
        bin  = c.fetch(:bin, "").to_s
        slurm = Adapters::Slurm::Batch.new(cluster: cluster, bin: bin)
        Adapters::Slurm.new(slurm: slurm)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Slurm
      # resource manager for job management.
      class Slurm < Adapter
        using Refinements::HashExtensions

        class Batch
          attr_reader :cluster
          attr_reader :bin

          class Error < StandardError; end

          def initialize(cluster:, bin: "")
            @cluster = cluster.to_s
            @bin     = Pathname.new(bin.to_s)
          end

          def fields
            {
              account: "%a",
              job_id: "%A",
              gres: "%b",
              exec_host: "%B",
              min_cpus: "%c",
              cpus: "%C",
              min_tmp_disk: "%d",
              nodes: "%D",
              end_time: "%e",
              dependency: "%E",
              features: "%f",
              array_job_id: "%F",
              group_name: "%g",
              group_id: "%G",
              over_subscribe: "%h",
              sockets_per_node: "%H",
              cores_per_socket: "%I",
              job_name: "%j",
              threads_per_core: "%J",
              comment: "%k",
              array_task_id: "%K",
              time_limit: "%l",
              time_left: "%L",
              min_memory: "%m",
              time_used: "%M",
              req_node: "%n",
              node_list: "%N",
              command: "%o",
              contiguous: "%O",
              qos: "%q",
              partition: "%P",
              priority: "%Q",
              reason: "%r",
              start_time: "%S",
              state_compact: "%t",
              state: "%T",
              user: "%u",
              user_id: "%U",
              reservation: "%v",
              submit_time: "%V",
              wckey: "%w",
              licenses: "%W",
              excluded_nodes: "%x",
              core_specialization: "%X",
              nice: "%y",
              scheduled_nodes: "%Y",
              sockets_cores_threads: "%z",
              work_dir: "%Z"
            }
          end

          def get_jobs(id: "", filters: [])
            options = filters.empty? ? fields : fields.slice(*filters)
            args  = ["--all", "--array", "--states=all", "--noconvert"]
            args += ["-o", "#{options.values.join("|")}"]
            args += ["-j", id.to_s] unless id.to_s.empty?
            lines = call("squeue", *args).split("\n").map(&:strip)

            jobs = []
            lines.drop(2).each do |line|
              jobs << Hash[options.keys.zip(line.split("|"))]
            end
            jobs
          end

          private
            def call(cmd, *args, env: {})
              cmd = bin.join(cmd.to_s).to_s
              args = ["-M", cluster] + args.map(&:to_s)
              env = env.to_h
              o, e, s = Open3.capture3(env, cmd, *args)
              s.success? ? o : raise(Error, e)
            end
        end

        # Mapping of state characters for Slurm
        STATE_MAP = {
          'BF' => :completed,  # BOOT_FAIL
          'CA' => :completed,  # CANCELLED
          'CD' => :completed,  # COMPLETED
          'CF' => :queued,     # CONFIGURING
          'CG' => :running,    # COMPLETING
          'F'  => :completed,  # FAILED
          'NF' => :completed,  # NODE_FAIL
          'PD' => :queued,     # PENDING
          'PR' => :completed,  # PREEMPTED
          'RV' => :completed,  # REVOKED
          'R'  => :running,    # RUNNING
          'SE' => :completed,  # SPECIAL_EXIT
          'ST' => :running,    # STOPPED
          'S'  => :suspended,  # SUSPENDED
          'TO' => :completed   # TIMEOUT
        }

        # Further mapping for reason of pending jobs in Slurm
        REASON_MAP = {
          'JobHeldAdmin' => :queued_held,
          'JobHeldUser'  => :queued_held
        }

        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :slurm The Slurm batch object
        def initialize(opts = {})
          o = opts.to_h.symbolize_keys

          @slurm = o.fetch(:slurm) { raise ArgumentError, "No slurm object specified. Missing argument: slurm" }
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
          headers.merge!(Join_Path: 'oe') if script.join_files
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
          if script.nodes && !script.nodes.empty?
            # Reduce an array to unique objects with count
            #   ["a", "a", "b"] #=> {"a" => 2, "b" => 1}
            nodes = script.nodes.group_by {|v| v}.each_with_object({}) {|(k, v), h| h[k] = v.size}
            resources.merge!(nodes: nodes.map {|k, v| k.is_a?(NodeRequest) ? node_request_to_str(k, v) : k }.join('+'))
          end

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

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job, otherwise get list of all jobs
        #   running on cluster
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info, Array<Info>] information describing submitted job
        # @see Adapter#info
        def info(id: "")
          id = id.to_s
          info_ary = @slurm.get_jobs(id: id).map do |v|
            allocated_nodes = parse_nodes(v[:node_list])
            Info.new(
              id: v[:job_id],
              status: REASON_MAP.fetch(v[:reason]) { STATE_MAP.fetch(v[:state_compact], :undetermined) },
              allocated_nodes: allocated_nodes,
              submit_host: nil,
              job_name: v[:job_name],
              job_owner: v[:user],
              accounting_id: v[:account],
              procs: v[:cpus],
              queue_name: v[:partition],
              wallclock_time: duration_in_seconds(v[:time_used]),
              cpu_time: nil,
              submission_time: Time.parse(v[:submit_time]),
              dispatch_time: v[:start_time] == "N/A" ? nil : Time.parse(v[:start_time]),
              native: v
            )
          end
          if info_ary.empty?
            # set completed status if can't find job id
            Info.new(
              id: id,
              status: :completed
            )
          elsif info_ary.size == 1
            info_ary.first
          else
            info_ary
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id:)
          if job = @slurm.get_jobs(id: id.to_s, filters: [:state_compact, :reason]).first
            Status.new(
              state: REASON_MAP.fetch(job[:reason]) { STATE_MAP.fetch(job[:state_compact], :undetermined) },
            )
          else
            # set completed status if can't find job id
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
        def hold(id:)
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
        def release(id:)
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
        def delete(id:)
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
            return 0 if time.nil?
            time, days = time.split("-").reverse
            days.to_i * 24 * 3600 +
              time.split(':').map { |v| v.to_i }.inject(0) { |total, v| total * 60 + v }
          end

          # Convert seconds to duration
          def seconds_to_duration(time)
            '%02d:%02d:%02d' % [time/3600, time/60%60, time%60]
          end

          # Convert host list string to individual nodes
          # "em082"
          # "em[014,055-056,161]"
          # "n0163/2,7,10-11+n0205/0-11+n0156/0-11"
          def parse_nodes(node_list)
            /^(?<prefix>[^\[]+)(\[(?<range>[^\]]+)\])?$/ =~ node_list

            if range
              range.split(",").map do |x|
                x =~ /^(\d+)-(\d+)$/ ? ($1..$2).to_a : x
              end.flatten.map do |n|
                { name: prefix + n, procs: nil }
              end
            else
              [ { name: prefix, procs: nil } ]
            end
          end

          # Convert a NodeRequest object to a valid Torque string
          def node_request_to_str(node, cnt)
            str = cnt.to_s
            str += ":ppn=#{node.procs}" if node.procs
            str += ":#{node.properties.join(':')}" if node.properties
            str
          end
      end
    end
  end
end
