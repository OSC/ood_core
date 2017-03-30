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
            delim = ";"     # don't use "|" because FEATURES uses this
            options = filters.empty? ? fields : fields.slice(*filters)
            args  = ["--all", "--array", "--states=all", "--noconvert"]
            args += ["-o", "#{options.values.join(delim)}"]
            args += ["-j", id.to_s] unless id.to_s.empty?
            lines = call("squeue", *args).split("\n").map(&:strip)

            jobs = []
            lines.drop(2).each do |line|
              jobs << Hash[options.keys.zip(line.split(delim))]
            end
            jobs
          end

          def hold_job(id)
            call("scontrol", "hold", id.to_s)
          end

          def release_job(id)
            call("scontrol", "release", id.to_s)
          end

          def delete_job(id)
            call("scancel", id.to_s)
          end

          def submit_string(str, args: [], env: {})
            args = args + ["--parsable"]
            call("sbatch", *args, env: env, stdin: str.to_s).strip.split(";").first
          end

          private
            def call(cmd, *args, env: {}, stdin: "")
              cmd = bin.join(cmd.to_s).to_s
              args = ["-M", cluster] + args.map(&:to_s)
              env = env.to_h
              o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
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

          # Set sbatch options
          args = []
          # TODO: script.args
          args += ["-H"] if script.submit_as_hold
          args += (script.rerunnable? ? ["--requeue"] : ["--norequeue"]) unless script.rerunnable.nil?
          args += ["-D", script.workdir.to_s] unless script.workdir.nil?
          args += ["--mail-user", script.email.first] unless script.email.nil?
          if script.email_on_started && script.email_on_terminated
            args += ["--mail-type", "ALL"]
          elsif script.email_on_started
            args += ["--mail-type", "BEGIN"]
          elsif script.email_on_terminated
            args += ["--mail-type", "END"]
          elsif script.email_on_started == false && script.email_on_terminated == false
            args += ["--mail-type", "NONE"]
          end
          args += ["-J", script.job_name] unless script.job_name.nil?
          args += ["-i", script.input_path] unless script.input_path.nil?
          args += ["-o", script.output_path] unless script.output_path.nil?
          args += ["-e", script.error_path] unless script.error_path.nil?
          # ignore join_files, by default it joins stdout and stderr unless error_path is specified
          args += ["--reservation", script.reservation_id] unless script.reservation_id.nil?
          args += ["--priority", script.priority] unless script.priority.nil?
          args += ["--begin", script.start_time.localtime.strftime("%C%y-%m-%dT%H:%M:%S")] unless script.start_time.nil?
          args += ["-A", script.accounting_id] unless script.accounting_id.nil?
          args += ["--mem", "#{script.min_phys_memory}K"] unless script.min_phys_memory.nil?
          args += ["-t", seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
          # ignore nodes, don't know how to do this for slurm

          # Set dependencies
          depend = []
          depend << "after:#{after.join(":")}"           unless after.empty?
          depend << "afterok:#{afterok.join(":")}"       unless afterok.empty?
          depend << "afternotok:#{afternotok.join(":")}" unless afternotok.empty?
          depend << "afterany:#{afterany.join(":")}"     unless afterany.empty?
          args += ["-d", depend.join(",")]               unless depend.empty?

          # Set environment variables
          env = script.job_environment || {}
          args += [
            "--export",
            script.job_environment.nil? ? "NONE" : script.job_environment.keys.join(",")
          ]

          # Set native options
          args += script.native if script.native

          # Submit job
          @slurm.submit_string(script.content, args: args, env: env)
        rescue Batch::Error => e
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
              status: get_state(v[:state_compact], v[:reason]),
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
            Status.new(state: get_state(job[:state_compact], job[:reason]))
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
          @slurm.hold_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id:)
          @slurm.release_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id:)
          @slurm.delete_job(id.to_s)
        rescue Batch::Error => e
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
            "%02d:%02d:%02d" % [time/3600, time/60%60, time%60]
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
            elsif prefix
              [ { name: prefix, procs: nil } ]
            else
              []
            end
          end

          # Get status symbol
          def get_state(st, reason)
            state = STATE_MAP.fetch(st, :undetermined)
            state == :queued ? REASON_MAP.fetch(reason, state) : state
          end
      end
    end
  end
end