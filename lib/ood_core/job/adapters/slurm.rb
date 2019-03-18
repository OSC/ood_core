require "time"
require "ood_core/refinements/hash_extensions"
require "ood_core/job/adapters/helper"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Slurm adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :cluster (nil) The cluster to communicate with
      # @option config [Object] :conf (nil) Path to the slurm conf
      # @option config [Object] :bin (nil) Path to slurm client binaries
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to Slurm client executables
      def self.build_slurm(config)
        c = config.to_h.symbolize_keys
        cluster = c.fetch(:cluster, nil)
        conf    = c.fetch(:conf, nil)
        bin     = c.fetch(:bin, nil)
        bin_overrides = c.fetch(:bin_overrides, {})
        slurm = Adapters::Slurm::Batch.new(cluster: cluster, conf: conf, bin: bin, bin_overrides: bin_overrides)
        Adapters::Slurm.new(slurm: slurm)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Slurm
      # resource manager for job management.
      class Slurm < Adapter
        using Refinements::HashExtensions

        # Object used for simplified communication with a Slurm batch server
        # @api private
        class Batch
          # The cluster of the Slurm batch server
          # @example CHPC's kingspeak cluster
          #   my_batch.cluster #=> "kingspeak"
          # @return [String, nil] the cluster name
          attr_reader :cluster

          # The path to the Slurm configuration file
          # @example For Slurm 10.0.0
          #   my_batch.conf.to_s #=> "/usr/local/slurm/10.0.0/etc/slurm.conf
          # @return [Pathname, nil] path to slurm conf
          attr_reader :conf

          # The path to the Slurm client installation binaries
          # @example For Slurm 10.0.0
          #   my_batch.bin.to_s #=> "/usr/local/slurm/10.0.0/bin
          # @return [Pathname] path to slurm binaries
          attr_reader :bin

          # Optional overrides for Slurm client executables
          # @example
          #  {'sbatch' => '/usr/local/bin/sbatch'}
          # @return Hash<String, String>
          attr_reader :bin_overrides

          # The root exception class that all Slurm-specific exceptions inherit
          # from
          class Error < StandardError; end

          # @param cluster [#to_s, nil] the cluster name
          # @param conf [#to_s, nil] path to the slurm conf
          # @param bin [#to_s] path to slurm installation binaries
          def initialize(cluster: nil, bin: nil, conf: nil, bin_overrides: {})
            @cluster = cluster && cluster.to_s
            @conf    = conf    && Pathname.new(conf.to_s)
            @bin     = Pathname.new(bin.to_s)
            @bin_overrides = bin_overrides
          end

          # Get a list of hashes detailing each of the jobs on the batch server
          # @example Status info for all jobs
          #   my_batch.get_jobs
          #   #=>
          #   #[
          #   #  {
          #   #    :account => "account",
          #   #    :job_id => "my_job",
          #   #    ...
          #   #  },
          #   #  {
          #   #    :account => "account",
          #   #    :job_id => "my_other_job",
          #   #    ...
          #   #  },
          #   #  ...
          #   #]
          # @param id [#to_s] the id of the job
          # @param filters [Array<Symbol>] list of attributes to filter on
          # @raise [Error] if `squeue` command exited unsuccessfully
          # @return [Array<Hash>] list of details for jobs
          def get_jobs(id: "", filters: [])
            record_separator = "\x1E"
            unit_separator = "\x1F"

            options = filters.empty? ? fields : fields.slice(*filters)
            args  = ["--all", "--states=all", "--noconvert"]
            args += ["-o", "#{options.values.join(unit_separator)}"]
            args += ["-j", id.to_s] unless id.to_s.empty?
            lines = call("squeue", *args).rstrip.chomp(record_separator).split(record_separator)

            lines.drop(cluster ? 2 : 1).map do |line|
              Hash[options.keys.zip(line.strip.split(unit_separator))]
            end
          end

          # Put a specified job on hold
          # @example Put job "1234" on hold
          #   my_batch.hold_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `scontrol` command exited unsuccessfully
          # @return [void]
          def hold_job(id)
            call("scontrol", "hold", id.to_s)
          end

          # Release a specified job that is on hold
          # @example Release job "1234" from on hold
          #   my_batch.release_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `scontrol` command exited unsuccessfully
          # @return [void]
          def release_job(id)
            call("scontrol", "release", id.to_s)
          end

          # Delete a specified job from batch server
          # @example Delete job "1234"
          #   my_batch.delete_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `scancel` command exited unsuccessfully
          # @return [void]
          def delete_job(id)
            call("scancel", id.to_s)
          end

          # Submit a script expanded as a string to the batch server
          # @param str [#to_s] script as a string
          # @param args [Array<#to_s>] arguments passed to `sbatch` command
          # @param env [Hash{#to_s => #to_s}] environment variables set
          # @raise [Error] if `sbatch` command exited unsuccessfully
          # @return [String] the id of the job that was created
          def submit_string(str, args: [], env: {})
            args = args.map(&:to_s) + ["--parsable"]
            env = {"SBATCH_EXPORT" => "NONE"}.merge env.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
            call("sbatch", *args, env: env, stdin: str.to_s).strip.split(";").first
          end

          private
            # Call a forked Slurm command for a given cluster
            def call(cmd, *args, env: {}, stdin: "")
              cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
              args  = args.map(&:to_s)
              args += ["-M", cluster] if cluster
              env = env.to_h
              env["SLURM_CONF"] = conf.to_s if conf
              o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
              s.success? ? o : raise(Error, e)
            end

            # Fields requested from a formatted `squeue` call
            # Note that the order of these fields is important
            def fields
              {
                account: "%a",
                job_id: "%A",
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
                array_job_task_id: "%i",
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
                work_dir: "%Z",
                gres: "%b",  # must come at the end to fix a bug with Slurm 18
              }
            end
        end

        # Mapping of state codes for Slurm
        STATE_MAP = {
          'BF' => :completed,  # BOOT_FAIL
          'CA' => :completed,  # CANCELLED
          'CD' => :completed,  # COMPLETED
          'CF' => :queued,     # CONFIGURING
          'CG' => :running,    # COMPLETING
          'F'  => :completed,  # FAILED
          'NF' => :completed,  # NODE_FAIL
          'PD' => :queued,     # PENDING
          'PR' => :suspended,  # PREEMPTED
          'RV' => :completed,  # REVOKED
          'R'  => :running,    # RUNNING
          'SE' => :completed,  # SPECIAL_EXIT
          'ST' => :running,    # STOPPED
          'S'  => :suspended,  # SUSPENDED
          'TO' => :completed   # TIMEOUT
        }

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :slurm The Slurm batch object
        # @see Factory.build_slurm
        def initialize(opts = {})
          o = opts.to_h.symbolize_keys

          @slurm = o.fetch(:slurm) { raise ArgumentError, "No slurm object specified. Missing argument: slurm" }
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
          after      = Array(after).map(&:to_s)
          afterok    = Array(afterok).map(&:to_s)
          afternotok = Array(afternotok).map(&:to_s)
          afterany   = Array(afterany).map(&:to_s)

          # Set sbatch options
          args = []
          # ignore args, don't know how to do this for slurm
          args += ["-H"] if script.submit_as_hold
          args += (script.rerunnable ? ["--requeue"] : ["--no-requeue"]) unless script.rerunnable.nil?
          args += ["-D", script.workdir.to_s] unless script.workdir.nil?
          args += ["--mail-user", script.email.join(",")] unless script.email.nil?
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
          args += ["--reservation", script.reservation_id] unless script.reservation_id.nil?
          args += ["-p", script.queue_name] unless script.queue_name.nil?
          args += ["--priority", script.priority] unless script.priority.nil?
          args += ["--begin", script.start_time.localtime.strftime("%C%y-%m-%dT%H:%M:%S")] unless script.start_time.nil?
          args += ["-A", script.accounting_id] unless script.accounting_id.nil?
          args += ["-t", seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
          args += ['-a', script.job_array_request] unless script.job_array_request.nil?
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
          args += ["--export", script.job_environment.keys.join(",")] unless script.job_environment.nil? || script.job_environment.empty?

          # Set native options
          args += script.native if script.native

          # Set content
          content = if script.shell_path.nil?
                      script.content
                    else
                      "#!#{script.shell_path}\n#{script.content}"
                    end

          # Submit job
          @slurm.submit_string(content, args: args, env: env)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          @slurm.get_jobs.map do |v|
            parse_job_info(v)
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          id = id.to_s
          info_ary = @slurm.get_jobs(id: id).map do |v|
            parse_job_info(v)
          end

          # If no job was found we assume that it has completed
          info_ary.empty? ? Info.new(id: id, status: :completed) : handle_job_array(info_ary, id)
        rescue Batch::Error => e
          # set completed status if can't find job id
          if /Invalid job id specified/ =~ e.message
            Info.new(
              id: id,
              status: :completed
            )
          else
            raise JobAdapterError, e.message
          end
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          id = id.to_s
          jobs = @slurm.get_jobs(
            id: id,
            filters: [:job_id, :array_job_task_id, :state_compact]
          )
          # A job id can return multiple jobs if it corresponds to a job array
          # id, so we need to find the job that corresponds to the given job id
          # (if we can't find it, we assume it has completed)
          #
          # Match against the job id or the formatted job & task id "1234_0"
          if job = jobs.detect { |j| j[:job_id] == id || j[:array_job_task_id] == id }
            Status.new(state: get_state(job[:state_compact]))
          else
            # set completed status if can't find job id
            Status.new(state: :completed)
          end
        rescue Batch::Error => e
          # set completed status if can't find job id
          if /Invalid job id specified/ =~ e.message
            Status.new(state: :completed)
          else
            raise JobAdapterError, e.message
          end
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          @slurm.hold_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job hold if can't find job id
          raise JobAdapterError, e.message unless /Invalid job id specified/ =~ e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          @slurm.release_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job release if can't find job id
          raise JobAdapterError, e.message unless /Invalid job id specified/ =~ e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          @slurm.delete_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job deletion if can't find job id
          raise JobAdapterError, e.message unless /Invalid job id specified/ =~ e.message
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
          # "c457-[011-012]"
          # "c438-[062,104]"
          # "c427-032,c429-002"
          def parse_nodes(node_list)
            node_list.to_s.scan(/([^,\[]+)(?:\[([^\]]+)\])?/).map do |prefix, range|
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
            end.flatten
          end

          # Determine state from Slurm state code
          def get_state(st)
            STATE_MAP.fetch(st, :undetermined)
          end

          # Parse hash describing Slurm job status
          def parse_job_info(v)
            allocated_nodes = parse_nodes(v[:node_list])
            if allocated_nodes.empty?
              if v[:scheduled_nodes] && v[:scheduled_nodes] != "(null)"
                allocated_nodes = parse_nodes(v[:scheduled_nodes])
              else
                allocated_nodes = [ { name: nil } ] * v[:nodes].to_i
              end
            end
            Info.new(
              id: v[:job_id],
              status: get_state(v[:state_compact]),
              allocated_nodes: allocated_nodes,
              submit_host: nil,
              job_name: v[:job_name],
              job_owner: v[:user],
              accounting_id: v[:account],
              procs: v[:cpus],
              queue_name: v[:partition],
              wallclock_time: duration_in_seconds(v[:time_used]),
              wallclock_limit: duration_in_seconds(v[:time_limit]),
              cpu_time: nil,
              submission_time: Time.parse(v[:submit_time]),
              dispatch_time: v[:start_time] == "N/A" ? nil : Time.parse(v[:start_time]),
              native: v
            )
          end

          def handle_job_array(info_ary, id)
            # If only one job was returned we return it
            return info_ary.first unless info_ary.length > 1

            parent_task_hash = {:tasks => []}

            info_ary.map do |task_info|
              parent_task_hash[:tasks] << {:id => task_info.id, :status => task_info.status}

              if task_info.id == id || task_info.native[:array_job_task_id] == id
                # Merge hashes without clobbering the child tasks
                parent_task_hash.merge!(task_info.to_h.select{|k, v| k != :tasks})
              end
            end

            Info.new(**parent_task_hash)
          end
      end
    end
  end
end
