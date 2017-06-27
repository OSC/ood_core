require "time"
require "ood_core/refinements/hash_extensions"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the PBS Pro adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :host (nil) The batch server host
      # @option config [Object] :exec (nil) Path to PBS Pro executables
      def self.build_pbspro(config)
        c = config.to_h.compact.symbolize_keys
        host = c.fetch(:host, nil)
        exec = c.fetch(:exec, nil)
        pbspro = Adapters::PBSPro::Batch.new(host: host, exec: exec)
        Adapters::PBSPro.new(pbspro: pbspro)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a PBS Pro
      # resource manager for job management.
      class PBSPro < Adapter
        using Refinements::HashExtensions

        # Object used for simplified communication with a PBS Pro batch server
        # @api private
        class Batch
          # The host of the PBS Pro batch server
          # @example
          #   my_batch.host #=> "my_batch.server.edu"
          # @return [String, nil] the batch server host
          attr_reader :host

          # The path containing the PBS executables
          # @example
          #   my_batch.exec.to_s #=> "/usr/local/pbspro/10.0.0
          # @return [Pathname, nil] path to pbs executables
          attr_reader :exec

          # The root exception class that all PBS Pro-specific exceptions
          # inherit from
          class Error < StandardError; end

          # @param host [#to_s, nil] the batch server host
          # @param exec [#to_s, nil] path to pbs executables
          def initialize(host: nil, exec: nil)
            @host = host && host.to_s
            @exec = exec && Pathname.new(exec.to_s)
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
            args = ["-f"]   # display all information
            args += ["-t"]  # list subjobs
            args += [id.to_s] unless id.to_s.empty?
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
            jobs.reject { |j| /\[\]/ =~ j[:job_id] } # drop main job array jobs
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
              cmd = exec.join("bin", cmd).to_s if exec
              args = args.map(&:to_s)
              env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
              env["PBS_DEFAULT"] = host.to_s if host
              env["PBS_EXEC"]    = exec.to_s if exec
              chdir ||= "."
              o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s, chdir: chdir.to_s)
              s.success? ? o : raise(Error, e)
            end
        end

        # Mapping of state codes for PBSPro
        STATE_MAP = {
          'Q' => :queued,
          'W' => :queued,         # job is waiting for its submitter-assigned start time to be reached
          'H' => :queued_held,
          'T' => :queued_held,    # job is being moved to a new location
          'M' => :completed,      # job was moved to another server
          'R' => :running,
          'S' => :suspended,
          'U' => :suspended,      # cycle-harvesting job is suspended due to keyboard activity
          'E' => :running,        # job is exiting after having run
          'F' => :completed,      # job is finished
          'X' => :completed       # subjob has completed execution or has been deleted
          # ignore B as it signifies a job array
        }

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :pbspro The PBS Pro batch object
        # @see Factory.build_pbspro
        def initialize(opts = {})
          o = opts.to_h.compact.symbolize_keys

          @pbspro = o.fetch(:pbspro) { raise ArgumentError, "No pbspro object specified. Missing argument: pbspro" }
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
          args += ["-h"] if script.submit_as_hold
          args += ["-r", script.rerunnable ? "y" : "n"] unless script.rerunnable.nil?
          args += ["-M", script.email.join(",")] unless script.email.nil?
          if script.email_on_started && script.email_on_terminated
            args += ["-m", "be"]
          elsif script.email_on_started
            args += ["-m", "b"]
          elsif script.email_on_terminated
            args += ["-m", "e"]
          end
          args += ["-N", script.job_name] unless script.job_name.nil?
          # ignore input_path (not defined in PBS Pro)
          args += ["-o", script.output_path] unless script.output_path.nil?
          args += ["-e", script.error_path] unless script.error_path.nil?
          # Reservations are actually just queues in PBS Pro
          args += ["-q", script.reservation_id] if !script.reservation_id.nil? && script.queue_name.nil?
          args += ["-q", script.queue_name] unless script.queue_name.nil?
          args += ["-p", script.priority] unless script.priority.nil?
          args += ["-a", script.start_time.localtime.strftime("%C%y%m%d%H%M.%S")] unless script.start_time.nil?
          args += ["-A", script.accounting_id] unless script.accounting_id.nil?
          args += ["-l", "walltime=#{seconds_to_duration(script.wall_time)}"] unless script.wall_time.nil?

          # Set dependencies
          depend = []
          depend << "after:#{after.join(":")}"           unless after.empty?
          depend << "afterok:#{afterok.join(":")}"       unless afterok.empty?
          depend << "afternotok:#{afternotok.join(":")}" unless afternotok.empty?
          depend << "afterany:#{afterany.join(":")}"     unless afterany.empty?
          args += ["-W", "depend=#{depend.join(",")}"]   unless depend.empty?

          # Set environment variables
          envvars = script.job_environment.to_h
          args += ["-v", envvars.map{|k,v| "#{k}=#{v}"}.join(",")] unless envvars.empty?

          # If error_path is not specified we join stdout & stderr (as this
          # mimics what the other resource managers do)
          args += ["-j", "oe"] if script.error_path.nil?

          # Set native options
          args += script.native if script.native

          # Submit job
          @pbspro.submit_string(script.content, args: args, chdir: script.workdir)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all
          @pbspro.get_jobs.map do |v|
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
          @pbspro.get_jobs(id: id).map do |v|
            parse_job_info(v)
          end.first || Info.new(id: id, status: :completed)
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
            Info.new(
              id: v[:job_id],
              status: get_state(v[:job_state]),
              allocated_nodes: allocated_nodes,
              submit_host: submit_host,
              job_name: v[:Job_Name],
              job_owner: job_owner,
              accounting_id: v[:Account_Name],
              procs: allocated_nodes.inject(0) { |sum, x| sum + x[:procs] },
              queue_name: v[:queue],
              wallclock_time: duration_in_seconds(v.fetch(:resources_used, {})[:walltime]),
              wallclock_limit: duration_in_seconds(v.fetch(:Resource_List, {})[:walltime]),
              cpu_time: duration_in_seconds(v.fetch(:resources_used, {})[:cput]),
              submission_time: v[:ctime] ? Time.parse(v[:ctime]) : nil,
              dispatch_time: v[:stime] ? Time.parse(v[:stime]) : nil,
              native: v
            )
          end
      end
    end
  end
end
