require "time"
require 'etc'
require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
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
      # @option config [Object] :submit_host ("") Submit job on login node via ssh
      # @option config [Object] :strict_host_checking (true) Whether to use strict host checking when ssh to submit_host
      def self.build_slurm(config)
        c = config.to_h.symbolize_keys
        cluster              = c.fetch(:cluster, nil)
        conf                 = c.fetch(:conf, nil)
        bin                  = c.fetch(:bin, nil)
        bin_overrides        = c.fetch(:bin_overrides, {})
        submit_host          = c.fetch(:submit_host, "")
        strict_host_checking = c.fetch(:strict_host_checking, true)
        slurm = Adapters::Slurm::Batch.new(cluster: cluster, conf: conf, bin: bin, bin_overrides: bin_overrides, submit_host: submit_host, strict_host_checking: strict_host_checking)
        Adapters::Slurm.new(slurm: slurm)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Slurm
      # resource manager for job management.
      class Slurm < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions

        # Get integer representing the number of gpus used by a node or job,
        # calculated from gres string
        # @return [Integer] the number of gpus in gres
        def self.gpus_from_gres(gres)
          gres.to_s.scan(/gpu[^(,]*[:=](\d+)/).flatten.map(&:to_i).sum
        end

        # Object used for simplified communication with a Slurm batch server
        # @api private
        class Batch
          UNIT_SEPARATOR = "\x1F"
          RECORD_SEPARATOR = "\x1E"

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

          # The login node where the job is submitted via ssh
          # @example owens.osc.edu
          # @return [String] The login node
          attr_reader :submit_host

          # Wheter to use strict host checking when ssh to submit_host
          # @example false
          # @return [Bool]; true if empty
          attr_reader :strict_host_checking

          # The root exception class that all Slurm-specific exceptions inherit
          # from
          class Error < StandardError; end

          # An error indicating the slurm command timed out
          class SlurmTimeoutError < Error; end

          # @param cluster [#to_s, nil] the cluster name
          # @param conf [#to_s, nil] path to the slurm conf
          # @param bin [#to_s] path to slurm installation binaries
          # @param bin_overrides [#to_h] a hash of bin ovverides to be used in job
          # @param submit_host [#to_s] Submits the job on a login node via ssh
          # @param strict_host_checking [Bool] Whether to use strict host checking when ssh to submit_host
          def initialize(cluster: nil, bin: nil, conf: nil, bin_overrides: {}, submit_host: "", strict_host_checking: true)
            @cluster              = cluster && cluster.to_s
            @conf                 = conf    && Pathname.new(conf.to_s)
            @bin                  = Pathname.new(bin.to_s)
            @bin_overrides        = bin_overrides
            @submit_host          = submit_host.to_s
            @strict_host_checking = strict_host_checking
          end

          # Get a ClusterInfo object containing information about the given cluster
          # @return [ClusterInfo] object containing cluster details
          def get_cluster_info
            node_cpu_info = call("sinfo", "-aho %A/%D/%C").strip.split('/')
            gres_length = call("sinfo", "-o %G").lines.map(&:strip).map(&:length).max + 2
            gres_lines = call("sinfo", "-ahNO ,nodehost,gres:#{gres_length},gresused:#{gres_length}")
                         .lines.uniq.map(&:split)
            ClusterInfo.new(active_nodes: node_cpu_info[0].to_i,
                            total_nodes: node_cpu_info[2].to_i,
                            active_processors: node_cpu_info[3].to_i,
                            total_processors: node_cpu_info[6].to_i,
                            active_gpus: gres_lines.sum { |line| Slurm.gpus_from_gres(line[2]) },
                            total_gpus: gres_lines.sum { |line| Slurm.gpus_from_gres(line[1]) }
            )
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
          # @param owner [String] the owner(s) of the job
          # @param attrs [Array<Symbol>, nil] list of attributes request when calling squeue
          # @raise [Error] if `squeue` command exited unsuccessfully
          # @return [Array<Hash>] list of details for jobs
          def get_jobs(id: "", owner: nil, attrs: nil)
            fields = squeue_fields(attrs)
            args = squeue_args(id: id, owner: owner, options: fields.values)

            #TODO: switch mock of Open3 to be the squeue mock script
            # then you can use that for performance metrics
            StringIO.open(call("squeue", *args)) do |output|
              advance_past_squeue_header!(output)

              jobs = []
              output.each_line(RECORD_SEPARATOR) do |line|
                # TODO: once you can do performance metrics you can test zip against some other tools
                # or just small optimizations
                # for example, fields is ALREADY A HASH and we are setting the VALUES to
                # "line.strip.split(unit_separator)" array
                #
                # i.e. store keys in an array, do Hash[[keys, values].transpose]
                #
                # or
                #
                # job = {}
                # keys.each_with_index { |key, index| [key] = values[index] }
                # jobs << job
                #
                # assuming keys and values are same length! if not we have an error!
                line = line.encode('UTF-8', invalid: :replace, undef: :replace)
                values = line.chomp(RECORD_SEPARATOR).strip.split(UNIT_SEPARATOR)
                jobs << Hash[fields.keys.zip(values)] unless values.empty?
              end
              jobs
            end
          rescue SlurmTimeoutError
            # TODO: could use a log entry here
            return [{ id: id, state: 'undetermined' }]
          end

          def accounts
            user = Etc.getlogin
            args = ['-nP', 'show', 'users', 'withassoc', 'format=account,cluster,partition,qos', 'where', "user=#{user}"]

            [].tap do |accts|
              call('sacctmgr', *args).each_line do |line|
                acct, cluster, queue, qos = line.split('|')
                next if acct.nil? || acct.chomp.empty?

                args = {
                  name: acct,
                  qos: qos.to_s.chomp.split(','),
                  cluster: cluster,
                  queue: queue.to_s.empty? ? nil : queue
                }
                info = OodCore::Job::AccountInfo.new(**args) unless acct.nil?
                accts << info unless acct.nil?
              end
            end
          end

          def squeue_fields(attrs)
            if attrs.nil?
              all_squeue_fields
            else
              all_squeue_fields.slice(*squeue_attrs_for_info_attrs(Array.wrap(attrs) + squeue_required_fields))
            end
          end

          def squeue_required_fields
            #TODO: does this need to include ::array_job_task_id?
            #TODO: does it matter that order of the output can vary depending on the arguments and if "squeue_required_fields" are included?
            # previously the order was "fields.keys"; i don't think it does
            [:job_id, :state_compact]
          end

          #TODO: write some barebones test for this? like 2 options and id or no id
          def squeue_args(id: "", owner: nil, options: [])
            args  = ["--all", "--states=all", "--noconvert"]
            args.concat ["-o", "#{RECORD_SEPARATOR}#{options.join(UNIT_SEPARATOR)}"]
            args.concat ["-u", owner.to_s] unless owner.to_s.empty?
            args.concat ["-j", id.to_s] unless id.to_s.empty?
            args
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
            env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
            call("sbatch", *args, env: env, stdin: str.to_s).strip.split(";").first
          end

          # Fields requested from a formatted `squeue` call
          # Note that the order of these fields is important
          def all_squeue_fields
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

          # Job info fields requested from a formatted `sacct` call
          def sacct_info_fields
            {
              # The user name of the user who ran the job.
              user: 'User',
              # The group name of the user who ran the job.
              group_name: 'Group',
              # Job Id for reference
              job_id: 'JobId',
              # The name of the job or job step
              job_name: 'JobName',
              # The job's elapsed time.
              elapsed: 'Elapsed',
              # Minimum required memory for the job
              req_mem: 'ReqMem',
              # Count of allocated CPUs
              alloc_cpus: 'AllocCPUS',
              # Number of requested CPUs.
              req_cpus: 'ReqCPUS',
              # What the timelimit was/is for the job
              time_limit: 'Timelimit',
              # Displays the job status, or state
              state: 'State',
              # The sum of the SystemCPU and UserCPU time used by the job or job step
              total_cpu: 'TotalCPU',
              # Maximum resident set size of all tasks in job.
              max_rss: 'MaxRSS',
              # Identifies the partition on which the job ran.
              partition: 'Partition',
              # The time the job was submitted. In the same format as End.
              submit_time: 'Submit',
              # Initiation time of the job. In the same format as End.
              start_time: 'Start',
              # Termination time of the job.
              end: 'End',
              # Trackable resources. These are the minimum resource counts requested by the job/step at submission time.
              gres: 'ReqTRES'
            }
          end

          def queues
            info_raw = call('scontrol', 'show', 'part', '-o')

            [].tap do |ret_arr|
              info_raw.each_line do |line|
                ret_arr << str_to_queue_info(line)
              end
            end
          end

          def all_sinfo_node_fields
            {
              procs: '%c',
              name: '%n',
              features: '%f'
            }
          end

          def nodes
            args = all_sinfo_node_fields.values.join(UNIT_SEPARATOR)
            output = call('sinfo', '-ho', "#{RECORD_SEPARATOR}#{args}")

            output.each_line(RECORD_SEPARATOR).map do |line|
              values = line.chomp(RECORD_SEPARATOR).strip.split(UNIT_SEPARATOR)

              next if values.empty?

              data = Hash[all_sinfo_node_fields.keys.zip(values)]
              data[:name] = data[:name].to_s.split(',').first
              data[:features] = data[:features].to_s.split(',')
              NodeInfo.new(**data)
            end.compact
          end

          def sacct_info(job_ids, states, from, to, show_steps)
            # https://slurm.schedmd.com/sacct.html
            fields = sacct_info_fields
            args = ['-P'] # Output will be delimited
            args.concat ['--delimiter', UNIT_SEPARATOR]
            args.concat ['-n'] # No header
            args.concat ['--units', 'G'] # Memory units in GB
            args.concat ['--allocations'] unless show_steps # Show statistics relevant to the job, not taking steps into consideration
            args.concat ['-o', fields.values.join(',')] # Required data
            args.concat ['--state', states.join(',')] unless states.empty? # Filter by these states
            args.concat ['-j', job_ids.join(',')] unless job_ids.empty? # Filter by these job ids
            args.concat ['-S', from] if from # Filter from This date
            args.concat ['-E', to] if to # Filter until this date

            jobs_info = []
            StringIO.open(call('sacct', *args)) do |output|
              output.each_line do |line|
                # Replace blank values with nil
                values = line.strip.split(UNIT_SEPARATOR).map{ |value| value.to_s.empty? ? nil : value }
                jobs_info << Hash[fields.keys.zip(values)] unless values.empty?
              end
            end
            jobs_info
          end

          private
            def str_to_queue_info(line)
              hsh = line.split(' ').map do |token|
                m = token.match(/^(?<key>\w+)=(?<value>.+)$/)
                [m[:key], m[:value]]
              end.to_h.symbolize_keys

              hsh[:name] = hsh[:PartitionName]
              hsh[:qos] =  hsh[:QoS].to_s == 'N/A' ? [] : hsh[:QoS].to_s.split(',')
              hsh[:allow_accounts] = if hsh[:AllowAccounts].nil? || hsh[:AllowAccounts].to_s == 'ALL'
                                       nil
                                     else
                                       hsh[:AllowAccounts].to_s.split(',')
                                     end

              hsh[:deny_accounts] = hsh[:DenyAccounts].nil? ? [] : hsh[:DenyAccounts].to_s.split(',')

              hsh[:tres] = case hsh[:TRES]
                           when nil, '(null)', ''
                             {}
                           else
                             hsh[:TRES].to_s.split(',').map { |str| str.split('=') }.to_h
                           end
              OodCore::Job::QueueInfo.new(**hsh)
            end

            # Modify the StringIO instance by advancing past the squeue header
            #
            # The first two "records" should always be discarded. Consider the
            # following squeue with -M output (invisible characters shown):
            #
            #   CLUSTER: slurm_cluster_name\n
            #   \x1EJOBID\x1F\x1FSTATE\n
            #   \x1E1\x1F\x1FR\n
            #   \x1E2\x1F\x1FPD\n
            #
            # Splitting on the record separator first gives the Cluster header,
            # and then the regular header. If -M or --cluster is not specified
            # the effect is the same because the record separator is at the
            # start of the format string, so the first "record" would simply be
            # empty.
            def advance_past_squeue_header!(squeue_output)
              2.times { squeue_output.gets(RECORD_SEPARATOR) }
            end

            # Call a forked Slurm command for a given cluster
            def call(cmd, *args, env: {}, stdin: "")
              cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)

              args  = args.map(&:to_s)
              args.concat ["-M", cluster] if cluster && !cmd.to_s.end_with?('sacctmgr')

              env = env.to_h
              env["SLURM_CONF"] = conf.to_s if conf

              cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking)
              o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)
              s.success? ? interpret_and_raise(o, e) : raise(Error, e)
            end

            # Helper function to raise an error based on the contents of stderr.
            # Slurm exits 0 even when the command fails, so we need to interpret stderr
            # to see if the command was actually successful.
            def interpret_and_raise(stdout, stderr)
              return stdout if stderr.empty?

              raise SlurmTimeoutError, stderr if /^slurm_load_jobs error: Socket timed out/.match(stderr)

              stdout
            end

            def squeue_attrs_for_info_attrs(attrs)
              attrs.map { |a|
                {
                  id: :job_id,
                  status: :state_compact,
                  allocated_nodes: [:node_list, :scheduled_nodes],
                  # submit_host: nil,
                  job_name: :job_name,
                  job_owner: :user,
                  accounting_id: :account,
                  procs: :cpus,
                  queue_name: :partition,
                  wallclock_time: :time_used,
                  wallclock_limit: :time_limit,
                  # cpu_time: nil,
                  submission_time: :submit_time,
                  dispatch_time: :start_time
                }.fetch(a, a)
              }.flatten
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
          'TO' => :completed,  # TIMEOUT
          'OOM' => :completed, # OUT_OF_MEMORY

          'BOOT_FAIL'     => :completed,
          'CANCELED'      => :completed,
          'COMPLETED'     => :completed,
          'DEADLINE'      => :completed,
          'FAILED'        => :completed,
          'NODE_FAIL'     => :completed,
          'OUT_OF_MEMORY' => :completed,
          'PENDING'       => :queued,
          'PREEMPTED'     => :completed,
          'RUNNING'       => :running,
          'REQUEUED'      => :queued,
          'REVOKED'       => :completed,
          'SUSPENDED'     => :suspended,
          'TIMEOUT'       => :completed,
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
          args.concat ["-H"] if script.submit_as_hold
          args.concat (script.rerunnable ? ["--requeue"] : ["--no-requeue"]) unless script.rerunnable.nil?
          args.concat ["-D", script.workdir.to_s] unless script.workdir.nil?
          args.concat ["--mail-user", script.email.join(",")] unless script.email.nil?
          if script.email_on_started && script.email_on_terminated
            args.concat ["--mail-type", "ALL"]
          elsif script.email_on_started
            args.concat ["--mail-type", "BEGIN"]
          elsif script.email_on_terminated
            args.concat ["--mail-type", "END"]
          elsif script.email_on_started == false && script.email_on_terminated == false
            args.concat ["--mail-type", "NONE"]
          end
          args.concat ["-J", script.job_name] unless script.job_name.nil?
          args.concat ["-i", script.input_path] unless script.input_path.nil?
          args.concat ["-o", script.output_path] unless script.output_path.nil?
          args.concat ["-e", script.error_path] unless script.error_path.nil?
          args.concat ["--reservation", script.reservation_id] unless script.reservation_id.nil?
          args.concat ["-p", script.queue_name] unless script.queue_name.nil?
          args.concat ["--priority", script.priority] unless script.priority.nil?
          args.concat ["--begin", script.start_time.localtime.strftime("%C%y-%m-%dT%H:%M:%S")] unless script.start_time.nil?
          args.concat ["-A", script.accounting_id] unless script.accounting_id.nil?
          args.concat ["-t", seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
          args.concat ['-a', script.job_array_request] unless script.job_array_request.nil?
          args.concat ['--qos', script.qos] unless script.qos.nil?
          args.concat ['--gpus-per-node', script.gpus_per_node] unless script.gpus_per_node.nil?
          args.concat ['-n', script.cores] unless script.cores.nil?
          # ignore nodes, don't know how to do this for slurm

          # Set dependencies
          depend = []
          depend << "after:#{after.join(":")}"           unless after.empty?
          depend << "afterok:#{afterok.join(":")}"       unless afterok.empty?
          depend << "afternotok:#{afternotok.join(":")}" unless afternotok.empty?
          depend << "afterany:#{afterany.join(":")}"     unless afterany.empty?
          args.concat ["-d", depend.join(",")]               unless depend.empty?

          # Set environment variables
          env = script.job_environment || {}
          args.concat ["--export", export_arg(env, script.copy_environment?)]

          # Set native options
          args.concat script.native if script.native

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

        # Retrieve info about active and total cpus, gpus, and nodes
        # @return [Hash] information about cluster usage
        def cluster_info
          @slurm.get_cluster_info
        end

        # Retrieve the accounts available to use  for the current user.
        #
        # @return [Array<String>] the accounts available to the user.
        def accounts
          @slurm.accounts
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          @slurm.get_jobs(attrs: attrs).map do |v|
            parse_job_info(v)
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve historic info for all completed jobs from the resource manager.
        #
        # Known options:
        # job_ids [Array<#to_s>] optional list of job ids to filter the results.
        # states [Array<#to_s>] optional list of job state codes.
        # Selects jobs based on their state during the time period given.
        # from [#to_s] optional date string to filter jobs in any state after the specified time.
        # If states are provided, filter jobs in these states after this period
        # to [#to_s] optional date string to filter jobs in any state before the specified time.
        # If states are provided, filter jobs in these states before this period.
        # show_steps [#Boolean] optional boolean to filter job steps from the results.
        #
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_historic
        def info_historic(opts: {})
          job_ids    = opts.fetch(:job_ids, [])
          states     = opts.fetch(:states, [])
          from       = opts.fetch(:from, nil)
          to         = opts.fetch(:to, nil)
          show_steps = opts.fetch(:show_steps, false)
          @slurm.sacct_info(job_ids, states, from, to, show_steps).map do |v|
            Info.new(
              id: v[:job_id],
              status: get_state(v[:state]),
              job_name: v[:job_name],
              job_owner: v[:user],
              procs: v[:alloc_cpus],
              queue_name: v[:partition],
              wallclock_time: duration_in_seconds(v[:elapsed]),
              wallclock_limit: duration_in_seconds(v[:time_limit]),
              cpu_time: duration_in_seconds(v[:total_cpu]),
              submission_time: parse_time(v[:submit_time]),
              dispatch_time: parse_time(v[:start_time]),
              native: v,
              gpus: self.class.gpus_from_gres(v[:gres])
            )
          end
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

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner, attrs: nil)
          owner = Array.wrap(owner).map(&:to_s).join(',')
          @slurm.get_jobs(owner: owner).map do |v|
            parse_job_info(v)
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
          id = id.to_s
          jobs = @slurm.get_jobs(
            id: id,
            attrs: [:job_id, :array_job_task_id, :state_compact]
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

        def directive_prefix
          '#SBATCH'
        end

        def queues
          @slurm.queues
        end

        def nodes
          @slurm.nodes
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

        # Parse date time string ignoring unknown values returned by Slurm
        def parse_time(date_time)
          return nil if date_time.empty? || %w[N/A NONE UNKNOWN].include?(date_time.to_s.upcase)

          Time.parse(date_time)
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

          # Parse the memory string returned by Slurm and return bytes
          def parse_memory(mem_str)
            unit = mem_str.match(/[KMGTP]/).to_s
            value = mem_str.match(/\d+/).to_s

            factor = {
              "K" => 1024,
              "M" => 1024**2,
              "G" => 1024**3,
              "T" => 1024**4,
              "P" => 1024**5
            }

            value.to_i * factor[unit]
          end

          # Parse hash describing Slurm job status
          def parse_job_info(v)
            # per cpu or per node
            memory_per = nil

            allocated_nodes = parse_nodes(v[:node_list])
            if allocated_nodes.empty?
              if v[:scheduled_nodes] && v[:scheduled_nodes] != "(null)"
                allocated_nodes = parse_nodes(v[:scheduled_nodes])
              else
                allocated_nodes = [ { name: nil } ] * v[:nodes].to_i
              end
            end

            if v[:min_memory] && !v[:min_memory].empty?
              # Slurm uses per CPU memory if --mem-per-cpu with 'Mc' output
              # or uses per node if --mem with 'M' output
              if v[:min_memory].end_with?('c')
                # memory per CPU
                memory_per = :cpu
              else
                # memory per node
                memory_per = :node
              end

              v[:memory_per] = memory_per
            end

            Info.new(
              id: v[:job_id],
              status: get_state(v[:state_compact]),
              allocated_nodes: allocated_nodes,
              submit_host: nil,
              job_name: v[:job_name],
              job_owner: v[:user],
              accounting_id: handle_null_account(v[:account]),
              procs: v[:cpus],
              queue_name: v[:partition],
              wallclock_time: duration_in_seconds(v[:time_used]),
              wallclock_limit: duration_in_seconds(v[:time_limit]),
              cpu_time: nil,
              submission_time: v[:submit_time] ? Time.parse(v[:submit_time]) : nil,
              dispatch_time: (v[:start_time].nil? || v[:start_time] == "N/A") ? nil : Time.parse(v[:start_time]),
              native: v.merge(min_memory: min_memory, memory_per: memory_per),
              gpus: self.class.gpus_from_gres(v[:gres]),
              total_memory: compute_total_memory(v, allocated_nodes)
            )
          end

          # Compute the total memory being used by a job
          # @return [Integer] total memory in bytes
          def compute_total_memory(v, allocated_nodes)
            #return nil unless v[:min_memory]

            # Retrieve the memory_per created in parse_job
            memory_per = v[:memory_per]&.to_sym
            min_memory = parse_memory(v[:min_memory])

            # Compute per-cpu or per-node
            case memory_per
            when :cpu
              min_memory * v[:cpus]
            when :node
              min_memory * allocated_nodes.count
            else
              nil
            end
          end

          # Replace '(null)' with nil
          def handle_null_account(account)
            (account != '(null)') ? account : nil
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


          # we default to export NONE, but SLURM defaults to ALL.
          # we do this bc SLURM setups a new environment, loading /etc/profile
          # and all giving 'module' function (among other things shells give),
          # where the PUN did not.
          # --export=ALL export the PUN's environment.
          def export_arg(env, copy_environment)
            if !env.empty? && !copy_environment
              env.keys.join(",")
            elsif !env.empty? && copy_environment
              "ALL," + env.keys.join(",")
            elsif env.empty? && copy_environment
              # only this option changes behaivor dramatically
              "ALL"
            else
              "NONE"
            end
          end
      end
    end
  end
end
