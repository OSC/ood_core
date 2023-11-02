require "time"
require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions
      
      # Build the Fujitsu TCS (Technical Computing Suite) adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :bin (nil) Path to Fujitsu TCS resource manager binaries
      # @option config [#to_h]  :bin_overrides ({}) Optional overrides to Fujitsu TCS resource manager executables
      # @option config [Object] :working_dir (nil) Working directory for submitting a batch script
      def self.build_fujitsu_tcs(config)
        c = config.to_h.symbolize_keys
        bin           = c.fetch(:bin, nil)
        bin_overrides = c.fetch(:bin_overrides, {})
        working_dir   = c.fetch(:working_dir, nil)
        fujitsu_tcs   = Adapters::Fujitsu_TCS::Batch.new(bin: bin, bin_overrides: bin_overrides, working_dir: working_dir)
        Adapters::Fujitsu_TCS.new(fujitsu_tcs: fujitsu_tcs)
      end
    end
    
    module Adapters
      # An adapter object that describes the communication with a Fujitsu TCS
      # resource manager for job management.
      class Fujitsu_TCS < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions
        
        # Object used for simplified communication with a Fujitsu TCS batch server
        # @api private
        class Batch
          # The path to the Fujitsu TCS binaries
          # @example 
          #   my_batch.bin.to_s #=> "/usr/local/fujitsu_tcs/10.0.0/bin"
          # @return [Pathname] path to Fujitsu TCS binaries
          attr_reader :bin

          # Optional overrides for Fujitsu TCS executables
          # @example
          #  {'pjsub' => '/usr/local/bin/pjsub'}
          # @return Hash<String, String>
          attr_reader :bin_overrides

          # Working directory for submitting a batch script
          # @example
          #   my_batch.working_dir #=> "HOME" or Dir.pwd
          attr_reader :working_dir

          # The root exception class that all Fujitsu TCS specific exceptions inherit
          # from
          class Error < StandardError; end

          # An error indicating the Fujitsu TCS command timed out
          class Fujitsu_TCS_TimeoutError < Error; end

          # @param bin [#to_s] path to Fujitsu TCS installation binaries
          # @param bin_overrides [#to_h] a hash of bin ovverides to be used in job
          # @param working_dir [] Working directory for submitting a batch script
          def initialize(bin: nil, bin_overrides: {}, working_dir: nil)
            @bin           = Pathname.new(bin.to_s)
            @bin_overrides = bin_overrides
            if working_dir == nil
              @working_dir = Dir.pwd
            elsif working_dir == "HOME"
              @working_dir   = Dir.home
            else
              raise(StandardError, "Unknown working_dir")
            end
          end

          # Get a list of hashes detailing each of the jobs on the batch server
          # @example Status info for all jobs
          #   my_batch.get_jobs
          #   #=>
          #   #[
          #   #  {
          #   #    :JOB_ID => "123",
          #   #    :JOB_NAME => "my_job",
          #   #    ...
          #   #  },
          #   #  {
          #   #    :JOB_ID => "125",
          #   #    :JOB_NAME => "my_other_job",
          #   #    ...
          #   #  },
          #   #  ...
          #   #]
          # @param id [#to_s] the id of the job
          # @param owner [String] the owner(s) of the job
          # @raise [Error] if `pjstat` command exited unsuccessfully
          # @return [Array<Hash>] list of details for jobs
          def get_jobs(id: "", owner: nil)
            args = ["-A", "-s", "--data", "--choose=jid,jnam,rscg,st,std,stde,adt,sdt,nnumr,usr,elpl,elp"]
            args.concat ["--filter", "jid=" + id.to_s] unless id.to_s.empty?
            args.concat ["--filter", "usr=" + owner.to_s] unless owner.to_s.empty?
            
            StringIO.open(call("pjstat", *args)) do |output|
              output.gets() # Skip header
              jobs = []
              output.each_line do |line|
                l = line.split(",")
                jobs << {:JOB_ID => l[1],  :JOB_NAME   => l[2],  :RSC_GRP    => l[3].split[0],
                         :ST     => l[4],  :STD        => l[5],  :STDE       => l[6],
                         :ACCEPT => l[7],  :START_DATE => l[8],  :NODES      => l[9].split(":")[0],
                         :USER   => l[10], :ELAPSE_LIM => l[11], :ELAPSE_TIM => l[12].split[0] }
              end
              jobs
            end
          rescue Fujitsu_TCS_TimeoutError
            return [{ JOB_ID: id, ST: 'undetermined' }]
          end

          # Put a specified job on hold
          # @example Put job "1234" on hold
          #   my_batch.hold_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `pjhold` command exited unsuccessfully
          # @return [void]
          def hold_job(id)
            call("pjhold", id.to_s)
          end

          # Release a specified job that is on hold
          # @example Release job "1234" from on hold
          #   my_batch.release_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `pjrls` command exited unsuccessfully
          # @return [void]
          def release_job(id)
            call("pjrls", id.to_s)
          end

          # Delete a specified job from batch server
          # @example Delete job "1234"
          #   my_batch.delete_job("1234")
          # @param id [#to_s] the id of the job
          # @raise [Error] if `pjdel` command exited unsuccessfully
          # @return [void]
          def delete_job(id)
            call("pjdel", id.to_s)
          end

          # Submit a script expanded as a string to the batch server
          # @param str [#to_s] script as a string
          # @param args [Array<#to_s>] arguments passed to `pjsub` command
          # @raise [Error] if `pjsub` command exited unsuccessfully
          # @return [String] the id of the job that was created
          def submit_string(str, args: [])
            args = args.map(&:to_s)
            call("pjsub", *args, stdin: str.to_s).split[5]
          end
          
          private
            # Call a forked Fujitsu TCS command
            def call(cmd, *args, stdin: "")
              cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
              args = args.map(&:to_s)
              Dir.chdir(working_dir) do
                o, e, s = Open3.capture3(cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)
                s.success? ? o : raise(Error, e)
              end
            end
        end

        # Mapping of state codes for Fujitsu TCS resource manager
        STATE_MAP = {
          'ACC' => :queued,    # Accepted job submission
          'RJT' => :completed, # Rejected job submission
          'QUE' => :queued,    # Waiting for job execution
          'RNA' => :queued,    # Acquiring resources required for job execution
          'RNP' => :running,   # Executing prologue
          'RUN' => :running,   # Executing job
          'RNE' => :running,   # Executing epilogue
          'RNO' => :running,   # Waiting for completion of job termination processing
          'SPP' => :suspended, # Suspend in progress
          'SPD' => :suspended, # Suspended
          'RSM' => :running,   # Resume in progress
          'EXT' => :completed, # Exited job end execution
          'CCL' => :completed, # Exited job execution by interruption
          'HLD' => :suspended, # In fixed state due to users
          'ERR' => :completed, # In fixed state due to an error
        }

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :the Fujitsu TCS batch object
        # @see Factory.build_fujitsu_tcs
        def initialize(opts = {})
          o = opts.to_h.symbolize_keys

          @fujitsu_tcs = o.fetch(:fujitsu_tcs) { raise ArgumentError, "No Fujitsu TCS object specified. Missing argument: fujitsu_tcs" }
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
          #after      = Array(after).map(&:to_s)
          #afterok    = Array(afterok).map(&:to_s)
          #afternotok = Array(afternotok).map(&:to_s)
          #afterany   = Array(afterany).map(&:to_s)
          if !after.empty? || !afterok.empty? || !afternotok.empty? || !afterany.empty?
            raise JobAdapterError, "Dependency between jobs has not implemented yet."
          end
          
          # Set pjsub options
          args = []
          args.concat (script.rerunnable ? ["--restart"] : ["--norestart"]) unless script.rerunnable.nil?
          args.concat ["--mail-list", script.email.join(",")] unless script.email.nil?
          if script.email_on_started && script.email_on_terminated
            args.concat ["-m", "b,e"]
          elsif script.email_on_started
            args.concat ["-m", "b"]
          elsif script.email_on_terminated
            args.concat ["-m", "e"]
          end

          args.concat ["-N", script.job_name] unless script.job_name.nil?
          args.concat ["-o", script.output_path] unless script.output_path.nil?
          if script.error_path.nil?
            args.concat ["-j"]
          else
            args.concat ["-e", script.error_path]
          end
          args.concat ["-L", "rscgrp=" + script.queue_name] unless script.queue_name.nil?
          args.concat ["-p", script.priority] unless script.priority.nil?
          
          # start_time: <%= Time.local(2023,11,22,13,4).to_i %> in form.yml.erb
          args.concat ["--at", script.start_time.localtime.strftime("%C%y%m%d%H%M")] unless script.start_time.nil?
          args.concat ["-L", "elapse=" + seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
          args.concat ["--bulk", "--sparam", script.job_array_request] unless script.job_array_request.nil?

          # Set environment variables
          envvars = script.job_environment.to_h
          args.concat ["-x", envvars.map{|k,v| "#{k}=#{v}"}.join(",")] unless envvars.empty?
          args.concat ["-X"] if script.copy_environment?

          # Set native options
          args.concat script.native[0].split if script.native
          
          # Set content
          content = if script.shell_path.nil?
                      script.content
                    else
                      "#!#{script.shell_path}\n#{script.content}"
                    end
          
          # Submit job
          @fujitsu_tcs.submit_string(content, args: args)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          @fujitsu_tcs.get_jobs().map do |v|
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
          info_ary = @fujitsu_tcs.get_jobs(id: id).map do |v|
            parse_job_info(v)
          end

          # If no job was found we assume that it has completed
          info_ary.empty? ? Info.new(id: id, status: :completed) : info_ary.first # @fujitsu_tcs.get_jobs() must return only one element.
        rescue Batch::Error => e
          # set completed status if can't find job id
          if /\[ERR\.\] PJM .+ Job .+ does not exist/ =~ e.message
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
          owner = Array.wrap(owner).map(&:to_s).join('+')
          @fujitsu_tcs.get_jobs(owner: owner).map do |v|
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
          jobs = @fujitsu_tcs.get_jobs(id: id)

          if job = jobs.detect { |j| j[:JOB_ID] == id }
            Status.new(state: get_state(job[:ST]))
          else
            # set completed status if can't find job id
            Status.new(state: :completed)
          end
        rescue Batch::Error => e
          # set completed status if can't find job id
          if /\[ERR\.\] PJM .+ Job .+ does not exist/ =~ e.message
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
          @fujitsu_tcs.hold_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job hold if can't find job id
          raise JobAdapterError, e.message unless /\[ERR\.\] PJM .+ Job .+ does not exist/ =~ e.message
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          @fujitsu_tcs.release_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job release if can't find job id
          raise JobAdapterError, e.message unless /\[ERR\.\] PJM .+ Job .+ does not exist/ =~ e.message
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          @fujitsu_tcs.delete_job(id.to_s)
        rescue Batch::Error => e
          # assume successful job deletion if can't find job id
          raise JobAdapterError, e.message unless /\[ERR\.\] PJM .+ Job .+ does not exist/ =~ e.message
        end

        def directive_prefix
          '#PJM'
        end

        private
          # Convert duration to seconds
          def duration_in_seconds(time)
            return 0 if time.nil? or time == "-"
            time, days = time.split("-").reverse
            days.to_i * 24 * 3600 +
              time.split(':').map { |v| v.to_i }.inject(0) { |total, v| total * 60 + v }
          end

          # Convert seconds to duration
          def seconds_to_duration(time)
            "%02d:%02d:%02d" % [time/3600, time/60%60, time%60]
          end

          # Determine state from Fujitsu TCS state code
          def get_state(st)
            STATE_MAP.fetch(st, :undetermined)
          end

          # Parse hash describing Fujitsu TCS job status
          def parse_job_info(v)
            Info.new(
              id: v[:JOB_ID],
              job_name: v[:JOB_NAME],
              status: get_state(v[:ST]),
              job_owner: v[:USER],
              dispatch_time: v[:START_DATE],
              wallclock_time: duration_in_seconds(v[:ELAPSE_TIM]),
              wallclock_limit: duration_in_seconds(v[:ELAPSE_LIM]),
              submission_time: v[:ACCEPT],
              queue_name: v[:RSC_GRP],
              native: v
            )
          end
      end
    end
  end
end
