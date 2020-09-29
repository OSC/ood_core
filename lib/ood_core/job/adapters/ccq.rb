require "ood_core/job/adapters/helper"
require "tempfile"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Cloudy Cluster adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :image (nil) The default VM image to use
      # @option config [Object] :cloud (gcp) The cloud provider being used [gcp,aws]
      # @option config [Object] :scheduler (nil) The name of the scheduler to use
      # @option config [Object] :sge_root (nil) Path to SGE root, note that
      # @option config [#to_h] :bin (nil) Path to CC client binaries
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to CC client executables
      def self.build_ccq(config)
        Adapters::CCQ.new(config.to_h.symbolize_keys)
      end
    end

    module Adapters

      class PromptError < StandardError; end

      class CCQ < Adapter
        using Refinements::ArrayExtensions

        attr_reader :image, :cloud, :scheduler, :bin, :bin_overrides, :jobid_regex

        def initialize(config)
          @image = config.fetch(:image, nil)
          @cloud = config.fetch(:cloud, gcp_provider)
          @scheduler = config.fetch(:scheduler, nil)
          @bin = config.fetch(:bin, '/opt/CloudyCluster/srv/CCQ')
          @bin_overrides = config.fetch(:bin_overrides, {})
          @jobid_regex = config.fetch(:jobid_regex, "job id is: (?<job_id>\\d+) you")
        end

        # Submit a job with the attributes defined in the job template instance
        # @param script [Script] script object that describes the script and
        #   attributes for the submitted job
        # @param after [#to_s, Array<#to_s>] not used
        # @param afterok [#to_s, Array<#to_s>] not used
        # @param afternotok [#to_s, Array<#to_s>] not used
        # @param afterany [#to_s, Array<#to_s>] not used
        # @return [String] the job id returned after successfully submitting a
        #   job
        # @see Adapter#submit
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          script_file = make_script_file(script.content)
          args = []

          # cluster configuration args
          args.concat ["-s", scheduler] unless scheduler.nil?
          args.concat [image_arg, image] unless image.nil?

          args.concat ["-o", script.output_path.to_s] unless script.output_path.nil?
          args.concat ["-e", script.error_path.to_s] unless script.error_path.nil?
          args.concat ["-tl", seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
          args.concat ["-js", script_file.path.to_s]

          args.concat script.native if script.native

          output = call("ccqsub", args: args)
          parse_job_id_from_ccqsub(output)
        ensure
          script_file.close
        end

        # Retrieve info for all jobs from the resource manager
        # @return [Array<Info>] information describing submitted jobs
        def info_all(attrs: nil)
          args = []
          args.concat ["-s", scheduler] unless scheduler.nil?

          stat_output = call("ccqstat", args: args)
          info_from_ccqstat(stat_output)
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @return [Info] information describing submitted job
        def info(id)
          args = []
          args.concat ["-s", scheduler] unless scheduler.nil?
          args.concat ["-ji", id]

          stat_output = call("ccqstat", args: args)

          # WARNING: code path differs here than info_all because the output
          # from ccqstat -ji $JOBID is much more data than just the 4
          # columns that ccqstat gives.
          info_from_ccqstat_extended(stat_output)
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          info(id).status
        end

        # This adapter does not implement hold and will always raise
        #   an exception.
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] always
        # @return [void]
        def hold(_)
          raise NotImplementedError, "subclass did not define #hold"
        end

        # This adapter does not implement release and will always raise
        #   an exception.
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] always
        # @return [void]
        def release(_)
          raise NotImplementedError, "subclass did not define #release"
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          call("ccqdel", args: [id])
        end

        def directive_prefix
          '#CC'
        end

        private

        # Mapping of state codes
        STATE_MAP =
        {
          'Error'         => :suspended,  # not running, but infrastructure still possibly exists
          'CreatingCG'    => :queued,     # creating control group
          'Pending'       => :queued,     # in queue
          'Submitted'     => :queued,     #
          'Provisioning'  => :queued,     # node is being provisioned
          'Running'       => :running,    #
          'Completed'     => :completed,  #
        }.freeze

        def gcp_provider
          'gcp'
        end

        def aws_provider
          'aws'
        end

        def image_arg
          if cloud == gcp_provider
            '-gcpgi'
          else
            '-awsami'
          end
        end

        def call(cmd, args: [], env: {}, stdin: "")
          cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
          args = args.map(&:to_s)
          env = env.to_h
          o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
          s.success? ? o : interpret_and_raise(e, cmd)
        end

        # helper function to interpret an error the command had given and
        # raise a different error.
        def interpret_and_raise(error, command)
          # a special case with CCQ that prompts the user for username & password
          # so let's be helpful and tell the user what to do.
          if error.end_with?("EOFError: EOF when reading a line\n")
            raise(
              PromptError,
              "The #{command} command was prompted. You need to generate the certificate " + 
              "manually in a shell by running 'ccqstat'\nand entering your username/password"
            )
          else
            raise(JobAdapterError, e.message)
          end
        end

        # Convert seconds to duration
        def seconds_to_duration(seconds)
          format("%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        end

        # helper to make a script file. We can't pipe it into ccq so we have to
        # write a file.
        def make_script_file(content)
          file = Tempfile.new(tmp_file_name)
          file.write(content.to_s)
          file.flush
          file
        end

        def tmp_file_name
          'ccq_ood_script_'
        end

        def ccqstat_regex
          /^(?<id>\S+)\s+(?<name>.+)\s+(?<username>\S+)\s+(?<scheduler>\S+)\s+(?<status>\S+)\s*$/
        end

        def parse_job_id_from_ccqsub(output)
          match_data = /#{jobid_regex}/.match(output)
          # match_data could be nil, OR re-configured jobid_regex could be looking for a different named group
          job_id = match_data&.named_captures&.fetch('job_id', nil)
          throw JobAdapterError.new "Could not extract job id out of ccqsub output '#{output}'" if job_id.nil?
          job_id
        end

        # parse an Ood::Job::Info object from extended ccqstat output
        def info_from_ccqstat_extended(data)
          raw = extended_data_to_hash(data)
          data_hash = { native: raw }
          data_hash[:status] = get_state(raw['status'])
          data_hash[:id] = raw['name']
          data_hash[:job_name] = raw['jobName']
          data_hash[:job_owner] = raw['userName']
          data_hash[:submit_host] = raw['submitHostInstanceId']
          data_hash[:dispatch_time] = raw['startTime'].to_i
          data_hash[:submission_time] = raw['dateSubmitted'].to_i
          data_hash[:queue_name] = raw['criteriaPriority']

          Info.new(data_hash)
        end

        # extended data is just lines of 'key: value' value, so parse
        # it and stick it all in a hash.
        def extended_data_to_hash(data)
          Hash[data.to_s.scan(/(\w+): (\S+)/)]
        end

        def info_from_ccqstat(data)
          infos = []

          data.to_s.lines.drop(1).each do |line|
            match_data = ccqstat_regex.match(line)
            infos << Info.new(ccqstat_match_to_hash(match_data)) if valid_ccqstat_match?(match_data)
          end

          infos
        end

        def ccqstat_match_to_hash(match)
          data_hash = {}
          data_hash[:id] = match.named_captures.fetch('id', nil)
          data_hash[:job_owner] = match.named_captures.fetch('username', nil)
          data_hash[:status] = get_state(match.named_captures.fetch('status', nil))

          # The regex leaves trailing empty spaces. There's no way to tell if they're _actually_
          # a part of the job name or not, so we assume they're not and add the rstrip.
          data_hash[:job_name] = match.named_captures.fetch('name', nil).to_s.rstrip

          data_hash
        end

        def valid_ccqstat_match?(match)
          !match.nil? && !match.named_captures.fetch('id', nil).nil?
        end

        def get_state(state)
          STATE_MAP.fetch(state, :undetermined)
        end
      end
    end
  end
end
