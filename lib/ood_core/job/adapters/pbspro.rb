require "time"
require "ood_core/refinements/hash_extensions"
require "ood_core/job/adapters/helper"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the PBS Pro adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :host (nil) The batch server host
      # @option config [Object] :submit_host ("") The login node where the job is submitted
      # @option config [Object] :strict_host_checking (true) Whether to use strict host checking when ssh to submit_host
      # @option config [Object] :exec (nil) Path to PBS Pro executables
      # @option config [Object] :qstat_factor (nil) Deciding factor on how to
      #   call qstat for a user
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to PBS Pro client executables
      def self.build_pbspro(config)
        c = config.to_h.compact.symbolize_keys
        host                 = c.fetch(:host, nil)
        submit_host          = c.fetch(:submit_host, "")
        strict_host_checking = c.fetch(:strict_host_checking, true)
        pbs_exec             = c.fetch(:exec, nil)
        qstat_factor         = c.fetch(:qstat_factor, nil)
        bin_overrides         = c.fetch(:bin_overrides, {})
        pbspro = Adapters::PBSPro::Batch.new(host: host, submit_host: submit_host, strict_host_checking: strict_host_checking, pbs_exec: pbs_exec, bin_overrides: bin_overrides)
        Adapters::PBSPro.new(pbspro: pbspro, qstat_factor: qstat_factor)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a PBS Pro
      # resource manager for job management.
      class PBSPro < Adapter
        using Refinements::ArrayExtensions
        using Refinements::HashExtensions

        # Object used for simplified communication with a PBS Pro batch server
        # @api private
        class Batch
          # The host of the PBS Pro batch server
          # @example
          #   my_batch.host #=> "my_batch.server.edu"
          # @return [String, nil] the batch server host
          attr_reader :host

          # The login node to submit the job via ssh
          # @example
          #   my_batch.submit_host #=> "my_batch.server.edu"
          # @return [String, nil] the login node
          attr_reader :submit_host

          # Whether to use strict host checking when ssh to submit_host
          # @example
          #   my_batch.strict_host_checking #=> "false"
          # @return [Bool, true] the login node; true if not present
          attr_reader :strict_host_checking

          # The path containing the PBS executables
          # @example
          #   my_batch.pbs_exec.to_s #=> "/usr/local/pbspro/10.0.0
          # @return [Pathname, nil] path to pbs executables
          attr_reader :pbs_exec

          # Optional overrides for PBS Pro client executables
          # @example
          #  {'qsub' => '/usr/local/bin/qsub'}
          # @return Hash<String, String>
          attr_reader :bin_overrides

          # The root exception class that all PBS Pro-specific exceptions
          # inherit from
          class Error < StandardError; end

          # @param host [#to_s, nil] the batch server host
          # @param submit_host [#to_s, nil] the login node to ssh to
          # @param strict_host_checking [bool, true] wheter to use strict host checking when ssh to submit_host
          # @param exec [#to_s, nil] path to pbs executables
          def initialize(host: nil, submit_host: "", strict_host_checking: true, pbs_exec: nil, bin_overrides: {})
            @host                 = host && host.to_s
            @submit_host          = submit_host && submit_host.to_s
            @strict_host_checking = strict_host_checking
            @pbs_exec             = pbs_exec && Pathname.new(pbs_exec.to_s)
            @bin_overrides        = bin_overrides
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
          # @raise [Error] if `qstat` command exited unsuccessfully
          # @return [Array<Hash>] list of details for jobs
          def get_jobs(id: "")
            args = ["-f", "-t"]   # display all information
            args.concat [id.to_s] unless id.to_s.empty?
            lines = call("qstat", *args).gsub("\n\t", "").split("\n").map(&:strip)

            jobs = []
            lines.each do |line|
              if /^Job Id: (?<job_id>.+)$/ =~ line
                jobs << { job_id: job_id }
              elsif /^(?<key>[^\s]+) = (?<value>.+)$/ =~ line
                hsh = jobs.last
                k1, k2 = key.split(".").map(&:to_sym)
                k2 ? ( hsh[k1] ||= {} and hsh[k1][k2] = value ) : ( hsh[k1] = value )
              end
            end

            jobs
          end

          # Select batch jobs from the batch server
          # @param args [Array<#to_s>] arguments passed to `qselect` command
          # @raise [Error] if `qselect` command exited unsuccessfully
          # @return [Array<String>] list of job ids that match selection
          #   criteria
          def select_jobs(args: [])
            call("qselect", *args).split("\n").map(&:strip)
          end

          # Put a specified job on hold
          # @example Put job "1234" on hold
          #   my_batch.hold_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `qhold` command exited unsuccessfully
          # @return [void]
          def hold_job(id)
            call("qhold", id.to_s)
          end

          # Release a specified job that is on hold
          # @example Release job "1234" from on hold
          #   my_batch.release_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `qrls` command exited unsuccessfully
          # @return [void]
          def release_job(id)
            call("qrls", id.to_s)
          end

          # Delete a specified job from batch server
          # @example Delete job "1234"
          #   my_batch.delete_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `qdel` command exited unsuccessfully
          # @return [void]
          def delete_job(id)
            call("qdel", id.to_s)
          end

          # Submit a script expanded as a string to the batch server
          # @param str [#to_s] script as a string
          # @param args [Array<#to_s>] arguments passed to `qsub` command
          # @param chdir [#to_s, nil] working directory where `qsub` is called
          # @raise [Error] if `qsub` command exited unsuccessfully
          # @return [String] the id of the job that was created
          def submit_string(str, args: [], chdir: nil)
            call("qsub", *args, stdin: str.to_s, chdir: chdir).strip
          end

          private
            # Call a forked PBS Pro command for a given batch server
            def call(cmd, *args, env: {}, stdin: "", chdir: nil)
              cmd = cmd.to_s
              bindir = (!!pbs_exec) ? pbs_exec.join("bin").to_s : ''
              cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bindir, bin_overrides)
              env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
              env["PBS_DEFAULT"] = host.to_s if host
              env["PBS_EXEC"]    = pbs_exec.to_s if pbs_exec
              cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking)
              chdir ||= "."
              o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s, chdir: chdir.to_s)
              s.success? ? o : raise(Error, e)
            end
        end

        # Mapping of state codes for PBSPro
        STATE_MAP = {
          'Q' => :queued,
          'W' => :queued_held,    # job is waiting for its submitter-assigned start time to be reached
          'H' => :queued_held,
          'T' => :queued_held,    # job is being moved to a new location
          'M' => :completed,      # job was moved to another server
          'R' => :running,
          'S' => :suspended,
          'U' => :suspended,      # cycle-harvesting job is suspended due to keyboard activity
          'E' => :running,        # job is exiting after having run
          'F' => :completed,      # job is finished
          'X' => :completed,      # subjob has completed execution or has been deleted
          'B' => :running         # job array has at least one child running
        }

        # What percentage of jobs a user owns out of all jobs, used to decide
        # whether we filter the owner's jobs from a `qstat` of all jobs or call
        # `qstat` on each of the owner's individual jobs
        # @return [Float] ratio of owner's jobs to all jobs
        attr_reader :qstat_factor

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :pbspro The PBS Pro batch object
        # @option opts [#to_f] :qstat_factor (0.10) The qstat deciding factor
        # @see Factory.build_pbspro
        def initialize(opts = {})
          o = opts.to_h.compact.symbolize_keys

          @pbspro = o.fetch(:pbspro) { raise ArgumentError, "No pbspro object specified. Missing argument: pbspro" }
          @qstat_factor = o.fetch(:qstat_factor, 0.10).to_f
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

          # Set qsub options
          args = []
          # ignore args, can't use these if submitting from STDIN
          args.concat ["-h"] if script.submit_as_hold
          args.concat ["-r", script.rerunnable ? "y" : "n"] unless script.rerunnable.nil?
          args.concat ["-M", script.email.join(",")] unless script.email.nil?
          if script.email_on_started && script.email_on_terminated
            args.concat ["-m", "be"]
          elsif script.email_on_started
            args.concat ["-m", "b"]
          elsif script.email_on_terminated
            args.concat ["-m", "e"]
          end
          args.concat ["-N", script.job_name] unless script.job_name.nil?
          args.concat ["-S", script.shell_path] unless script.shell_path.nil?
          # ignore input_path (not defined in PBS Pro)
          args.concat ["-o", script.output_path] unless script.output_path.nil?
          args.concat ["-e", script.error_path] unless script.error_path.nil?
          # Reservations are actually just queues in PBS Pro
          args.concat ["-q", script.reservation_id] if !script.reservation_id.nil? && script.queue_name.nil?
          args.concat ["-q", script.queue_name] unless script.queue_name.nil?
          args.concat ["-p", script.priority] unless script.priority.nil?
          args.concat ["-a", script.start_time.localtime.strftime("%C%y%m%d%H%M.%S")] unless script.start_time.nil?
          args.concat ["-A", script.accounting_id] unless script.accounting_id.nil?
          args.concat ["-l", "walltime=#{seconds_to_duration(script.wall_time)}"] unless script.wall_time.nil?

          # Set dependencies
          depend = []
          depend << "after:#{after.join(":")}"           unless after.empty?
          depend << "afterok:#{afterok.join(":")}"       unless afterok.empty?
          depend << "afternotok:#{afternotok.join(":")}" unless afternotok.empty?
          depend << "afterany:#{afterany.join(":")}"     unless afterany.empty?
          args.concat ["-W", "depend=#{depend.join(",")}"]   unless depend.empty?

          # Set environment variables
          envvars = script.job_environment.to_h
          args.concat ["-v", envvars.map{|k,v| "#{k}=#{v}"}.join(",")] unless envvars.empty?
          args.concat ["-V"] if script.copy_environment?

          # If error_path is not specified we join stdout & stderr (as this
          # mimics what the other resource managers do)
          args.concat ["-j", "oe"] if script.error_path.nil?

          args.concat ["-J", script.job_array_request] unless script.job_array_request.nil?

          # Set native options
          args.concat script.native if script.native

          # Submit job
          @pbspro.submit_string(script.content, args: args, chdir: script.workdir)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          @pbspro.get_jobs.map do |v|
            parse_job_info(v)
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

      # Retrieve info for all jobs for a given owner or owners from the
      # resource manager
      # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
      # @raise [JobAdapterError] if something goes wrong getting job info
      # @return [Array<Info>] information describing submitted jobs
      def info_where_owner(owner, attrs: nil)
        owner = Array.wrap(owner).map(&:to_s)

        usr_jobs = @pbspro.select_jobs(args: ["-u", owner.join(",")])
        all_jobs = @pbspro.select_jobs(args: ["-T"])

        # `qstat` all jobs if user has too many jobs, otherwise `qstat` each
        # individual job (default factor is 10%)
        if usr_jobs.size > (qstat_factor * all_jobs.size)
          super
        else
          begin
            user_job_infos = []
            usr_jobs.each do |id|
              job = info(id)
              user_job_infos << job

              job.tasks.each {|task| user_job_infos << job.build_child_info(task)}
            end

            user_job_infos
          rescue Batch::Error => e
            raise JobAdapterError, e.message
          end
        end
      end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)
          id = id.to_s

          job_infos = @pbspro.get_jobs(id: id).map do |v|
            parse_job_info(v)
          end

          if job_infos.empty?
            Info.new(id: id, status: :completed)
          elsif job_infos.length == 1
            job_infos.first
          else
            process_job_array(id, job_infos)
          end
        rescue Batch::Error => e
          # set completed status if can't find job id
          if /Unknown Job Id/ =~ e.message || /Job has finished/ =~ e.message
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
          info(id.to_s).status
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          @pbspro.hold_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job hold if can't find job id
          raise JobAdapterError, e.message unless /Unknown Job Id/ =~ e.message || /Job has finished/ =~ e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          @pbspro.release_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job release if can't find job id
          raise JobAdapterError, e.message unless /Unknown Job Id/ =~ e.message || /Job has finished/ =~ e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          @pbspro.delete_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job deletion if can't find job id
          raise JobAdapterError, e.message unless /Unknown Job Id/ =~ e.message || /Job has finished/ =~ e.message
        end

        def directive_prefix
          '#PBS'
        end

        private
          # Convert duration to seconds
          def duration_in_seconds(time)
            time.nil? ? nil : time.split(':').map { |v| v.to_i }.inject(0) { |total, v| total * 60 + v }
          end

          # Convert seconds to duration
          def seconds_to_duration(time)
            "%02d:%02d:%02d" % [time/3600, time/60%60, time%60]
          end

          # Convert host list string to individual nodes
          # "hosta/J1+hostb/J2*P+..."
          # where J1 and J2 are an index of the job on the named host and P is the number of
          # processors allocated from that host to this job. P does not appear if it is 1.
          # Example: "i5n14/2*7" uses 7 procs on node "i5n14"
          def parse_nodes(node_list)
            node_list.split('+').map do |n|
              name, procs_list = n.split('/')
              procs = (procs_list.split('*')[1] || 1).to_i
              {name: name, procs: procs}
            end
          end

          # Determine state from PBS Pro state code
          def get_state(st)
            STATE_MAP.fetch(st, :undetermined)
          end

          # Parse hash describing PBS Pro job status
          def parse_job_info(v)
            /^(?<job_owner>[\w-]+)@(?<submit_host>.+)$/ =~ v[:Job_Owner]
            allocated_nodes = parse_nodes(v[:exec_host] || "")
            procs = allocated_nodes.inject(0) { |sum, x| sum + x[:procs] }
            if allocated_nodes.empty? # fill in with requested resources
              allocated_nodes = [ { name: nil } ] * v.fetch(:Resource_List, {})[:nodect].to_i
              procs = v.fetch(:Resource_List, {})[:ncpus].to_i
            end
            Info.new(
              id: v[:job_id],
              status: get_state(v[:job_state]),
              allocated_nodes: allocated_nodes,
              submit_host: submit_host,
              job_name: v[:Job_Name],
              job_owner: job_owner,
              accounting_id: v[:Account_Name],
              procs: procs,
              queue_name: v[:queue],
              wallclock_time: duration_in_seconds(v.fetch(:resources_used, {})[:walltime]),
              wallclock_limit: duration_in_seconds(v.fetch(:Resource_List, {})[:walltime]),
              cpu_time: duration_in_seconds(v.fetch(:resources_used, {})[:cput]),
              submission_time: v[:ctime] ? Time.parse(v[:ctime]) : nil,
              dispatch_time: v[:stime] ? Time.parse(v[:stime]) : nil,
              native: v
            )
          end

          # Combine the array parent with the states of its children
          def process_job_array(id, jobs)
            parent_job = jobs.select { |j| /\[\]/ =~ j.id }.first
            parent = (parent_job) ? parent_job.to_h : {:id => id, :status => :undetermined}

            # create task hashes from children
            parent[:tasks] = jobs.reject { |j| /\[\]/ =~ j.id }.map do |j|
              {
                :id => j.id,
                :status => j.status.to_sym,
                :wallclock_time => j.wallclock_time
              }
            end

            Info.new(**parent)
          end
      end
    end
  end
end
