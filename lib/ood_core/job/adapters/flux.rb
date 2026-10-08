require "etc"
require "json"
require "open3"
require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"

module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Flux adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :bin (nil) Path to the Flux client binaries
      # @option config [#to_h] :bin_overrides ({}) Optional overrides to Flux client executables
      # @option config [Object] :submit_host ("") Submit job on login node via ssh
      # @option config [Object] :strict_host_checking (true) Whether to use strict host checking when ssh to submit_host
      # @option config [Object] :flux_uri (nil) URI of the Flux instance to talk to;
      #   leave unset to use the system instance
      def self.build_flux(config)
        c = config.to_h.symbolize_keys
        bin                  = c.fetch(:bin, nil)
        bin_overrides        = c.fetch(:bin_overrides, {})
        submit_host          = c.fetch(:submit_host, "")
        strict_host_checking = c.fetch(:strict_host_checking, true)
        flux_uri             = c.fetch(:flux_uri, nil)

        flux = Adapters::Flux::Batch.new(
          bin: bin, bin_overrides: bin_overrides, submit_host: submit_host,
          strict_host_checking: strict_host_checking, flux_uri: flux_uri
        )
        Adapters::Flux.new(flux: flux)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Flux
      # resource manager for job management.
      #
      # Job ids are stored and returned in decimal. Flux prints ids in F58
      # (e.g. "ƒiFkbMhFM") by default, which doesn't belong in URLs, file
      # paths or batch connect session files. Every flux command
      # accepts decimal ids as input.
      class Flux < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions

        # Object used for simplified communication with Flux
        # @api private
        class Batch
          # The path to the Flux client installation binaries
          # @return [Pathname, nil]
          attr_reader :bin

          # Optional overrides for Flux client executables
          # @example
          #  {'flux' => '/usr/local/bin/flux'}
          # @return Hash<String, String>
          attr_reader :bin_overrides

          # The login node where commands are run via ssh
          # @return [String]
          attr_reader :submit_host

          # Whether to use strict host checking when ssh to submit_host
          # @return [Bool]
          attr_reader :strict_host_checking

          # URI of the Flux instance, or nil for the system instance
          # @return [String, nil]
          attr_reader :flux_uri

          # The root exception class that all Flux-specific exceptions inherit
          # from
          class Error < StandardError; end

          def initialize(bin: nil, bin_overrides: {}, submit_host: "", strict_host_checking: true, flux_uri: nil)
            @bin                  = Pathname.new(bin.to_s)
            @bin_overrides        = bin_overrides
            @submit_host          = submit_host.to_s
            @strict_host_checking = strict_host_checking
            @flux_uri             = flux_uri && flux_uri.to_s
          end

          # Submit a batch script on stdin
          # @param str [#to_s] the script content
          # @param args [Array<#to_s>] arguments to `flux batch`
          # @return [String] the job id, in decimal
          def submit_string(str, args: [])
            out = call("batch", *args, stdin: str.to_s)
            JobId.to_decimal(out)
          end

          # Get the json description of one job
          # @param id [#to_s] the job id
          # @return [Hash] the job, with symbol keys
          def get_job(id)
            out = call("jobs", "--json", id.to_s)
            parse_jobs(out).first
          end

          # Get the json descriptions of active jobs
          # @param owner [#to_s, nil] limit to this user; nil means all users
          # @return [Array<Hash>] the jobs, with symbol keys
          def get_jobs(owner: nil)
            args = owner.nil? ? ["-A"] : ["-u", owner.to_s]
            out = call("jobs", "--json", *args)
            parse_jobs(out)
          end

          def hold_job(id)
            call("job", "urgency", id.to_s, "hold")
          end

          def release_job(id)
            call("job", "urgency", id.to_s, "default")
          end

          def delete_job(id)
            call("cancel", id.to_s)
          end

          private

          # `flux jobs --json ID` prints one job object. Without an id it
          # prints {"jobs": [...]}.
          def parse_jobs(out)
            return [] if out.strip.empty?

            data = JSON.parse(out, symbolize_names: true)
            data.key?(:jobs) ? data[:jobs] : [data]
          rescue JSON::ParserError => e
            raise Error, "could not parse flux output: #{e.message}"
          end

          # Call a flux subcommand
          def call(subcommand, *args, stdin: "")
            cmd = OodCore::Job::Adapters::Helper.bin_path("flux", bin, bin_overrides)
            args = [subcommand] + args.map(&:to_s)

            env = {}
            env["FLUX_URI"] = flux_uri if flux_uri

            cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking, env)
            o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)

            # Flux writes UTF-8 whatever the locale is. F58 ids start with
            # "ƒ", and they show up in error messages too.
            raise Error, utf8(e) unless s.success?

            utf8(o)
          end

          def utf8(str)
            str.dup.force_encoding(Encoding::UTF_8)
          end
        end

        # Convert Flux job ids to decimal.
        # @api private
        module JobId
          # The base58 alphabet Flux uses for F58 ids (RFC 19)
          F58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".freeze

          # Flux prefixes F58 ids with "ƒ", or "f" when the locale isn't UTF-8
          F58_PREFIX = /\A[ƒf]/.freeze

          # @param id [#to_s] a job id in decimal or F58
          # @return [String] the job id in decimal
          def self.to_decimal(id)
            str = id.to_s.dup.force_encoding(Encoding::UTF_8).strip
            return str if str.match?(/\A\d+\z/)

            unless str.match?(F58_PREFIX)
              raise Batch::Error, "unrecognized flux job id: #{str.inspect}"
            end

            digits = str.sub(F58_PREFIX, "")
            number = 0
            digits.each_char do |char|
              value = F58_ALPHABET.index(char)
              raise Batch::Error, "unrecognized flux job id: #{str.inspect}" if value.nil?

              number = (number * 58) + value
            end
            number.to_s
          end
        end

        # Maps Flux job states (RFC 21) to OOD job states. A pending job
        # with urgency 0 is held, see #get_state.
        STATE_MAP = {
          "NEW"      => :queued,
          "DEPEND"   => :queued,
          "PRIORITY" => :queued,
          "SCHED"    => :queued,
          "RUN"      => :running,
          "CLEANUP"  => :running,
          "INACTIVE" => :completed
        }.freeze

        # Urgency Flux gives a held job
        HOLD_URGENCY = 0

        # Flux reports "no time limit" as a duration of 0
        UNLIMITED_DURATION = 0

        # PATH for jobs submitted with a cleared environment
        SYSTEM_PATH = "/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin".freeze

        # @api private
        # @param opts [#to_h] the options defining this adapter
        # @option opts [Batch] :flux The Flux batch object
        # @see Factory.build_flux
        def initialize(opts = {})
          o = opts.to_h.symbolize_keys

          @flux = o.fetch(:flux) { raise ArgumentError, "No flux object specified. Missing argument: flux" }
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
        # @return [String] the job id, in decimal
        # @see Adapter#submit
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          unless script.job_array_request.nil?
            raise JobAdapterError, "Flux does not support job arrays"
          end

          args = []
          args.concat ["--urgency=hold"] if script.submit_as_hold
          args.concat ["--cwd", script.workdir.to_s] unless script.workdir.nil?
          args.concat ["--job-name", script.job_name] unless script.job_name.nil?
          args.concat ["--input", script.input_path.to_s] unless script.input_path.nil?
          args.concat ["--output", script.output_path.to_s] unless script.output_path.nil?
          args.concat ["--error", script.error_path.to_s] unless script.error_path.nil?
          args.concat ["-q", script.queue_name] unless script.queue_name.nil?
          args.concat ["--bank", script.accounting_id] unless script.accounting_id.nil?
          args.concat ["-t", "#{script.wall_time.to_i}s"] unless script.wall_time.nil?
          # flux batch won't submit without a size, so default to one slot
          # (one core), like a bare sbatch
          if script.cores
            args.concat ["-n", script.cores.to_s]
          elsif !size_in_native?(script.native)
            args.concat ["-n", "1"]
          end
          unless script.start_time.nil?
            # Relative, so it's right even if OnDemand and Flux disagree on timezone
            offset = [(script.start_time.to_time - Time.now).round, 0].max
            args.concat ["--begin-time", "+#{offset}s"]
          end

          args.concat dependency_args("afterstart", after)
          args.concat dependency_args("afterok", afterok)
          args.concat dependency_args("afternotok", afternotok)
          args.concat dependency_args("afterany", afterany)

          args.concat env_args(script.job_environment || {}, script.copy_environment?)

          args.concat script.native if script.native

          @flux.submit_string(script_content(script), args: args)
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all active jobs from the resource manager
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          @flux.get_jobs.map { |job| parse_job_info(job) }
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        # Retrieve info for all active jobs of a given owner or owners
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner, attrs: nil)
          Array.wrap(owner).map(&:to_s).uniq.flat_map do |user|
            @flux.get_jobs(owner: user).map { |job| parse_job_info(job) }
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
          job = @flux.get_job(id)
          job.nil? ? Info.new(id: id, status: :completed) : parse_job_info(job)
        rescue Batch::Error => e
          # Flux forgets inactive jobs eventually, so an unknown job is done
          raise JobAdapterError, e.message unless unknown_job?(e)

          Info.new(id: id, status: :completed)
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def status(id)
          info(id).status
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          @flux.hold_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message unless unknown_job?(e)
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          @flux.release_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message unless unknown_job?(e)
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          @flux.delete_job(id.to_s)
        rescue Batch::Error => e
          raise JobAdapterError, e.message unless unknown_job?(e)
        end

        def directive_prefix
          "# flux:"
        end

        # Whether the adapter supports job arrays
        # @return [Boolean] - false
        def supports_job_arrays?
          false
        end

        # Whether the adapter supports job dependencies
        # @return [Boolean] - true
        def supports_job_dependencies?
          true
        end

        private

        # `flux batch` needs a shebang on the script
        def script_content(script)
          if script.shell_path
            "#!#{script.shell_path}\n#{script.content}"
          elsif script.content.start_with?("#!")
            script.content
          else
            "#!/bin/bash\n#{script.content}"
          end
        end

        # Whether native args already size the job: -N, -n, --nodes, --nslots
        def size_in_native?(native)
          Array(native).any? do |arg|
            arg.to_s.match?(/\A(-[Nn](\d+)?|--nodes(=.*)?|--nslots(=.*)?)\z/)
          end
        end

        # One --dependency per job id
        def dependency_args(type, ids)
          Array(ids).map { |id| "--dependency=#{type}:#{id}" }
        end

        # Flux copies the whole submit environment into the job by default.
        # OOD's default is to copy nothing, so clear it first unless
        # copy_environment is set.
        #
        # Clearing leaves the job with almost nothing: no HOME, USER or PATH,
        # and a login shell (#!/bin/bash -l) doesn't bring PATH back. Slurm
        # doesn't have this problem because --export=NONE implies
        # --get-user-env. So set a small default environment, like the
        # Kubernetes adapter's default_env. Nothing in it is copied from the
        # PUN's environment. job_environment wins over these.
        def env_args(env, copy_environment)
          args = []
          unless copy_environment
            args << "--env=-*"
            user_keys = env.keys.map(&:to_s)
            default_env.each do |key, value|
              args << "--env=#{key}=#{value}" unless user_keys.include?(key)
            end
          end
          env.each do |key, value|
            args << "--env=#{key}=#{value}"
          end
          args
        end

        # The user's identity from the user database (by uid; Etc.getlogin
        # can return nil in a process with no terminal, like a PUN), and a
        # PATH that finds flux inside the job.
        def default_env
          user = Etc.getpwuid(Process.uid)
          {
            "USER"    => user.name,
            "LOGNAME" => user.name,
            "HOME"    => user.dir,
            "SHELL"   => user.shell,
            "PATH"    => job_path
          }
        end

        # System directories, with the configured flux bin directory first so
        # `flux run` works inside batch scripts at sites that install it
        # elsewhere
        def job_path
          bin = @flux.bin.to_s
          bin.empty? ? SYSTEM_PATH : "#{bin}:#{SYSTEM_PATH}"
        end

        def unknown_job?(error)
          error.message.match?(/unknown/i)
        end

        def get_state(job)
          state = STATE_MAP.fetch(job[:state].to_s, :undetermined)
          return :queued_held if state == :queued && job[:urgency] == HOLD_URGENCY

          state
        end

        # Flux reports times as float seconds since the epoch
        def parse_time(value)
          value.nil? ? nil : Time.at(value)
        end

        def wallclock_limit(job)
          duration = job[:duration]
          return nil if duration.nil? || duration.to_i == UNLIMITED_DURATION

          duration.to_i
        end

        # A pending job has no nodelist yet, only a node count
        def allocated_nodes(job)
          names = expand_nodelist(job[:nodelist])
          return names.map { |name| { name: name } } unless names.empty?

          [{ name: nil }] * job[:nnodes].to_i
        end

        # Expand a hostlist like "node[1-3,7]" or "a,b[01-02]"
        def expand_nodelist(nodelist)
          nodelist.to_s.scan(/([^,\[]+)(?:\[([^\]]+)\])?/).flat_map do |prefix, range|
            if range
              range.split(",").flat_map do |part|
                part =~ /\A(\d+)-(\d+)\z/ ? ($1..$2).to_a : [part]
              end.map { |suffix| prefix + suffix }
            else
              [prefix]
            end
          end
        end

        def parse_job_info(job)
          Info.new(
            id: job[:id].to_s,
            status: get_state(job),
            allocated_nodes: allocated_nodes(job),
            submit_host: nil,
            job_name: job[:name],
            job_owner: job[:username],
            accounting_id: job[:bank],
            procs: job[:ncores],
            queue_name: job[:queue],
            wallclock_time: job[:runtime] && job[:runtime].to_i,
            wallclock_limit: wallclock_limit(job),
            cpu_time: nil,
            submission_time: parse_time(job[:t_submit]),
            dispatch_time: parse_time(job[:t_run]),
            native: job
          )
        end
      end
    end
  end
end
