require "time"
require 'etc'
require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"

require 'json'
require 'pathname'

module OodCore
  module Job
		class Factory
 
      using Refinements::HashExtensions
			# Build the PSIJ adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :bin (nil) Path to PSIJ binaries
      # @option config [#to_h]  :bin_overrides ({}) Optional overrides to PSIJ executables
			def self.build_psij(config)
        c = config.to_h.symbolize_keys
        cluster              = c.fetch(:cluster, nil)
        conf                 = c.fetch(:conf, nil)
        bin                  = c.fetch(:bin, nil)
        bin_overrides        = c.fetch(:bin_overrides, {})
        submit_host          = c.fetch(:submit_host, "")
        strict_host_checking = c.fetch(:strict_host_checking, true)
        executor             = c.fetch(:executor, nil)
        queue_name           = c.fetch(:queue_name, nil)
        psij = Adapters::PSIJ::Batch.new(cluster: cluster, conf: conf, bin: bin, bin_overrides: bin_overrides, submit_host: submit_host, strict_host_checking: strict_host_checking, executor: executor, queue_name: queue_name)
        Adapters::PSIJ.new(psij: psij)
      end
		end

		module Adapters
      class PSIJ < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions
        class Batch

          attr_reader :cluster
          attr_reader :conf
          attr_reader :bin
          attr_reader :bin_overrides
          attr_reader :submit_host
          attr_reader :strict_host_checking
          attr_reader :executor
          attr_reader :queue_name

          class Error < StandardError; end

          def initialize(cluster: nil, bin: nil, conf: nil, bin_overrides: {}, submit_host: "", strict_host_checking: true, executor: nil, queue_name: nil)
            @cluster              = cluster && cluster.to_s
            @conf                 = conf    && Pathname.new(conf.to_s)
            @bin                  = Pathname.new(bin.to_s)
            @bin_overrides        = bin_overrides
            @submit_host          = submit_host.to_s
            @strict_host_checking = strict_host_checking
            @executor             = executor
            @queue_name           = queue_name
          end

          def get_jobs(id: "", owner: nil)
            id = id.to_s.strip()
            params = {
              id: id,
              executor: executor,
            }
            args = params.map { |k, v| "--#{k}=#{v}" }
            get_info_path = Pathname.new(__FILE__).dirname.expand_path.join("psij/get_info.py").to_s
            jobs_data = call("python3", get_info_path, *args)
            jobs_data = JSON.parse(jobs_data, symbolize_names: true)
            jobs_data
          end

          def submit_job_path(args: [], chdir: nil, stdin: nil)
            submit_path = Pathname.new(__FILE__).dirname.expand_path.join("psij/submit.py").to_s
            call("python3", submit_path, *args, chdir: chdir, stdin: stdin)
          end

          def delete_job(args: [])
            delete_path = Pathname.new(__FILE__).dirname.expand_path.join("psij/delete.py").to_s
            call("python3", delete_path, *args)
          rescue => e
            raise JobAdapterError, e
          end

          def hold_job(args: [])
            hold_path = Pathname.new(__FILE__).dirname.expand_path.join("psij/hold.py").to_s
            call("python3", hold_path, *args)
          end

          def release_job(args: [])
            release_path = Pathname.new(__FILE__).dirname.expand_path.join("psij/release.py").to_s
            call("python3", release_path, *args)
          end

          def seconds_to_duration(time)
            "%02d:%02d:%02d" % [time/3600, time/60%60, time%60]
          end

          private
            # Call a forked psij script for a given cluster
            def call(cmd, *args, env: {}, stdin: "", chdir: nil)
              cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
              cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking)
              chdir ||= "."
              o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin, chdir: chdir.to_s)
              s.success? ? o : raise(Error, e)
            end

        end
        

        STATE_MAP = {
          'NEW'           => :undetermined,
          'QUEUED'        => :queued,
          'HELD'          => :queued_held,
          'ACTIVE'        => :running,
          'COMPLETED'     => :completed,
        }

        def initialize(opts = {})
          o = opts.to_h.symbolize_keys
        
          @psij = o.fetch(:psij) { raise ArgumentError, "No psij object specified. Missing argument: psij" }
        end
        

        # The `submit` method saves a job script as a file and prepares a command to submit the job.
        # Each optional argument specifies job dependencies (after, afterok, afternotok, afterany).
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          # convert OOD interfaces to PSI/J interfaces.
          # Conterted variables are shown as follows:
          #       OOD           |   PSI/J(JobSpec)
          # --------------------+----------------------------------------------------
          # submit_as_hold      |       X (not support)
          # rerunnable          |       X
          # email_on_started    |       X
          # email_on_terminated |       X
          # args                |   JobAttributes.custom_attributes
          # job_environment     |   environment
          # workdir             |   directory
          # email               |       X
          # job_name            |   name
          # shell_path          |   #!<shell_path>
          # input_path          |   stdin_path
          # output_path         |   stdout_path
          # error_path          |   stderr_path
          # reservation_id      |   JobAttributes.reservation_id
          # queue_name          |   JobAttributes.queue_name
          # priority            |       X
          # start_time          |       X
          # wall_time           |   JobAttributes.duration
          # accounting_id       |   JobAttributes.account or project_name(duplicated)
          # job_array_request   |       X
          # qos                 |       X
          # gpus_per_node       |   ResourceSpec.gpu_cores_per_process
          # native              |   executable (join script.content)
          # copy_environment    |   inherit_envrionment
          # cores               |   ResourceSpec.cpu_cores_per_process
          # after               |       X
          # afterok             |       X
          # afternotok          |       X
          # afterany            |       X
          # OOD does not have following PSI/J's interfaces.
          #   JobSpec class:
          #     pre_launch, post_launch, launcher
          #   ResourceSpec class:
          #     node_count, process_count, processes_per_node, exclusive_node_use

          content = if script.shell_path.nil?
            script.content
          else
            "#!#{script.shell_path}\n#{script.content}"
          end

          if ! script.native.nil?
            native = script.native.join("\n") unless script.native.nil?
            script.content.concat(native)
          end

          relative_path = "~/ood_tmp/run.sh"
          full_path = File.expand_path("~/ood_tmp/run.sh")
          FileUtils.mkdir_p(File.dirname(full_path))
          File.open(full_path, "w") do |file|
            file.write(content)
          end

          File.chmod(0755, full_path)

          # convert OOD interfaces to PSI/J interfaces.
          params = {
            environment: script.job_environment,
            directory: script.workdir,
            name: script.job_name,
            executable: relative_path,
            stdin_path: script.input_path,
            stdout_path: script.output_path,
            stderr_path: script.error_path,
            inherit_environment: script.copy_environment,
            attributes: {queue_name: script.queue_name,
                         reservation_id: script.reservation_id,
                         account: script.accounting_id,
                         duration: script.wall_time,
                         custom_attributes: script.args},
            resources: {__version: 1,
                        gpu_cores_per_process: script.gpus_per_node,
                        cpu_cores_per_process: script.cores}
          }

          if params[:attributes][:queue_name].nil?
            params[:attributes][:queue_name] = @psij.queue_name
          end
          if params[:stdout_path].nil?
            params[:stdout_path] = File.join(Dir.pwd, "stdout.txt")
          end
          if params[:stderr_path].nil?
            params[:stderr_path] = File.join(Dir.pwd, "stderr.txt")
          end

          # add script.native to params[:attributes][:custom_attributes] of PSI/J.
          if script.native && !script.native.empty?
            if params[:attributes][:custom_attributes].nil?
              params[:attributes][:custom_attributes] = script.native
            else
              params[:attributes][:custom_attributes].concat(script.native)
            end
          end
          # Add script.native to params[:attributes][:cutsom_attributes] of PSI/J.
          # Convert script.native array to hash.
          # ['--<name>', 'value'] -> {name: value}
          # ['--<name1>', '--<name2>'] -> {name1: "", name2: ""}
          if ! params[:attributes][:custom_attributes].nil? 
            hash = {}
            skip = false
            len = params[:attributes][:custom_attributes].length()-1
            for index in 0..len do
              if skip
                skip = false
                next
              end
              v = params[:attributes][:custom_attributes][index]
              has_hyphen = false
              if v.start_with?("--")
                name = v[2..-1]
                has_hyphen = true
              elsif v.start_with?("-")
                name = v[1..-1]
                has_hyphen = true
              else   
                name = v
              end
              if index == len || !has_hyphen || params[:attributes][:custom_attributes][index+1].start_with?("-")
                # if next value is not exist or start with "-", set empty string
                hash[name] = ""
              else
                # if next value is exist and not start with "-", set value
                hash[name] = params[:attributes][:custom_attributes][index+1]
                skip = true
              end
            end
            params[:attributes][:custom_attributes] = hash
          end

          # reject key which has nil value.
          params[:attributes] = params[:attributes].reject {|_, value |value.nil?}
          params[:resources] = params[:resources].reject {|_, value |value.nil?}
          data = params.reject {|_, value |value.nil?}
          
          # serialize params to JSON
          args = []
          args[0] = @psij.executor

          @psij.submit_job_path(args: args, chdir: script.workdir, stdin: JSON.generate(data))
        rescue Batch::Error => e
          raise JobAdapterError, e
        end

        def cluster_info
        end

        def accounts
        end
        
        def delete(id)
          id = id.to_s.strip()
          params = {
            id: id,
            executor: @psij.executor,
          }
          args = params.map { |k, v| "--#{k}=#{v}" }
          @psij.delete_job(args: args)
        rescue Batch::Error => e
          raise JobAdapterError, e.message unless /Invalid job id specified/ =~ e.message
        end

        def hold(id)
          id = id.to_s.strip()
          params = {
            id: id,
            executor: @psij.executor,
          }
          args = params.map { |k, v| "--#{k}=#{v}" }
          @psij.hold_job(args: args)
        rescue Batch::Error => e
          raise JobAdapterError, e.message unless /Invalid job id specified/ =~ e.message
        end

        def release(id)
          id = id.to_s.strip()
          params = {
            id: id,
            executor: @psij.executor,
          }
          args = params.map { |k, v| "--#{k}=#{v}" }
          @psij.release_job(args: args)
        rescue Batch::Error => e
          raise JobAdapterError, e.message unless /Invalid job id specified/ =~ e.message
        end


        def info(id)
          id = id.to_s

          job_infos = @psij.get_jobs(id: id).map do |v|
            parse_job_info(v)
          end

          if job_infos.empty?
            Info.new(id: id, status: :completed)
          else
            job_infos.first
          end
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

        def info_all(attrs: nil)
          @psij.get_jobs.map do |v|
            parse_job_info(v)
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        def info_where_owner(owner, attrs: nil)
          owner = Array.wrap(owner).map(&:to_s).join(',')
          @psij.get_jobs(owner: owner).map do |v|
            parse_job_info(v)
          end
        rescue Batch::Error => e
          raise JobAdapterError, e.message
        end

        def status(id)
          info(id.to_s).status
        end

        def directive_prefix
        end

        private
          def get_state(st)
            STATE_MAP.fetch(st, :undetermined)
          end

          def parse_job_info(v)
            # parse input hash to Info object
            # if v don't have :reosurcelist, set empty array
            if v[:resourcelist].nil? || v[:resourcelist].empty?
              allocated_nodes = [ { name: "" } ]
            else
              allocated_nodes = v[:resourcelist]
            end
            if v[:cpu_time].nil?
              cpu_time = nil
            else
              cpu_time = v[:cpu_time].to_i
            end
            Info.new(
              id: v[:native_id],
              status: get_state(v[:current_state]),
              allocated_nodes: allocated_nodes,
              submit_host: v[:submit_host],
              job_name: v[:name],
              job_owner: v[:owner],
              accounting_id: v[:account],
              procs: v[:process_count] ? v[:process_count].to_i : 0,
              queue_name: v[:queue_name],
              wallclock_time: v[:wall_time],
              wallclock_limit: v[:duration],
              cpu_time: cpu_time,
              submission_time: v[:submission_time] ? Time.parse(v[:submission_time]): nil,
              dispatch_time: v[:dispatch_time] ? Time.parse(v[:dispatch_time]): nil,
              native: v
            )
          end

      end
    end
  end
end
