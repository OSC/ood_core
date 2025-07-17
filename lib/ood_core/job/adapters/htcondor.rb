require "time"
require 'etc'
require 'tempfile'
require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"

module OodCore
    module Job
        class Factory
            using Refinements::HashExtensions

            # Build the HTCondor adapter from a configuration
            # @param config [#to_h] the configuration for job adapter
            # @option config [Object] :bin (nil) Path to HTCondor client binaries
            # @option config [Object] :submit_host ("") Submit job on login node via ssh
            # @option config [Object] :strict_host_checking (true) Whether to use strict host checking when ssh to submit_host
            def self.build_htcondor(config)
                c = config.to_h.symbolize_keys
                bin                  = c.fetch(:bin, nil)
                bin_overrides        = c.fetch(:bin_overrides, {})
                submit_host          = c.fetch(:submit_host, "")
                strict_host_checking = c.fetch(:strict_host_checking, true)
                default_universe = c.fetch(:default_universe, "vanilla")
                default_docker_image = c.fetch(:default_docker_image, "ubuntu:latest")
                user_group_map = c.fetch(:user_group_map, nil)
                cluster = c.fetch(:cluster, "")
                additional_attributes = c.fetch(:additional_attributes, {})
                htcondor = Adapters::HTCondor::Batch.new(bin: bin, bin_overrides: bin_overrides,
                    submit_host: submit_host, strict_host_checking: strict_host_checking,
                    default_universe: default_universe,
                    default_docker_image: default_docker_image, 
                    user_group_map: user_group_map,
                    cluster: cluster,
                    additional_attributes: additional_attributes,
                    )
                Adapters::HTCondor.new(htcondor: htcondor)
            end
        end

        module Adapters
            # An adapter object that describes the communication with an HTCondor
            # resource manager for job management.
            class HTCondor < Adapter
                using Refinements::HashExtensions
                using Refinements::ArrayExtensions

                # Object used for simplified communication with an HTCondor batch server
                # @api private
                class Batch
                    # The path to the HTCondor client installation binaries
                    # @return [Pathname] path to HTCondor binaries
                    attr_reader :bin

                    # The path to the HTCondor client installation binaries that override
                    # the default binaries
                    # @return [Pathname] path to HTCondor binaries overrides
                    attr_reader :bin_overrides

                    # The login node where the job is submitted via ssh
                    # @return [String] The login node
                    attr_reader :submit_host

                    # Whether to use strict host checking when ssh to submit_host
                    # @return [Bool]; true if empty
                    attr_reader :strict_host_checking

                    # Default universe for jobs submitted to HTCondor
                    # @return [String] the default universe for jobs
                    attr_reader :default_universe

                    # Default docker image for jobs submitted to HTCondor
                    # @return [String] the default docker image for jobs
                    attr_reader :default_docker_image

                    # A path to the user/group map for HTCondor jobs
                    # The format in the file should adhere to the format used by [AssignAccountingGroup](https://htcondor.readthedocs.io/en/latest/admin-manual/introduction-to-configuration.html#FEATURE:ASSIGNACCOUNTINGGROUP)
                    # @return [String,nil] the path to the user/group map file
                    attr_reader :user_group_map

                    # The cluster name for this HTCondor instance
                    # @return [String] the cluster name
                    attr_reader :cluster

                    # Additional attributes to be added to the job submission
                    # @return [Hash{#to_s => #to_s}] additional attributes to be added to the job submission
                    attr_reader :additional_attributes

                    # The root exception class that all HTCondor-specific exceptions inherit
                    # from
                    class Error < StandardError; end

                    # @param bin [#to_s] path to HTCondor installation binaries
                    # @param submit_host [#to_s] Submits the job on a login node via ssh
                    # @param strict_host_checking [Bool] Whether to use strict host checking when ssh to submit_host
                    def initialize(bin: nil, bin_overrides: {}, submit_host: "", strict_host_checking: false, default_universe: "vanilla", default_docker_image: "ubuntu:latest", user_group_map: nil, cluster: "", additional_attributes: {})
                        @bin                  = Pathname.new(bin.to_s)
                        @bin_overrides        = bin_overrides
                        @submit_host          = submit_host.to_s
                        @strict_host_checking = strict_host_checking
                        @default_universe     = default_universe.to_s
                        @default_docker_image = default_docker_image.to_s
                        @user_group_map       = user_group_map.to_s unless user_group_map.nil?
                        @cluster              = cluster.to_s
                        @additional_attributes = additional_attributes
                    end

                    # Submit a script to the batch server
                    # @param args [Array<#to_s>] arguments passed to `condor_submit` command
                    # @param env [Hash{#to_s => #to_s}] environment variables set
                    # @param script [String] the script to submit
                    # @raise [Error] if `condor_submit` command exited unsuccessfully
                    # @return [String] the id of the job that was created
                    def submit_string(args: [], script_args: [], env: {}, script: "")
                        args = args.map(&:to_s)
                        script_args = script_args.map(&:to_s).map { |s| s.to_s.gsub('"', "'") } # cannot do double 
                        env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }

                        tempfile = Tempfile.new("htcondor_submit")
                        tempfile.close
                        path = tempfile.path
                        tempfile.unlink # unlink the tempfile so it can be used by condor_submit

                        call("bash", "-c", "cat > #{path}", stdin: script)
                        output = call("condor_submit", *args, env: env, stdin: "arguments=#{path.split("/").last} #{script_args.join(" ")}\ntransfer_input_files=#{path}").strip

                        match = output.match(/(cluster )?(\d+)/)
                        raise Error, "Failed to parse job ID from output: #{output}" unless match
                        match[2]

                    end

                    # Run the `condor_rm` command to remove a job
                    # @param id [#to_s] the id of the job to remove
                    # @raise [Error] if `condor_rm` command exited unsuccessfully
                    def remove_job(id)
                        call("condor_rm", id.to_s)
                    rescue Error => e
                        raise Error, "Failed to remove job #{id}: #{e.message}"
                    end

                    # Place a job on hold using `condor_hold`
                    # @param id [#to_s] the id of the job to hold
                    # @raise [Error] if `condor_hold` command exited unsuccessfully
                    def hold_job(id)
                        id = id.to_s
                        call("condor_hold", id)
                    rescue Error => e
                        raise Error, "Failed to hold job #{id}: #{e.message}"
                    end

                    # Release a job from hold using `condor_release`
                    # @param id [#to_s] the id of the job to release
                    # @raise [Error] if `condor_release` command exited unsuccessfully
                    def release_job(id)
                        id = id.to_s
                        call("condor_release", id)
                    rescue Error => e
                        raise Error, "Failed to release job #{id}: #{e.message}"
                    end

                    # Retrieve job information using `condor_q`
                    # @param id [#to_s] the id of the job
                    # @param owner [String] the owner(s) of the job
                    # @raise [Error] if `condor_q` command exited unsuccessfully
                    # @return [Array<Hash>] list of details for jobs
                    def get_jobs(id: "", owner: nil)
                        args = []
                        args.concat ["-constraint", "ClusterId == #{id}"] unless id.to_s.empty?
                        args.concat ["-constraint", "Owner == \"#{owner}\""] unless owner.to_s.empty?
                        args.concat ["-af", "ClusterId", "JobStatus", "Owner", "AcctGroup", "JobBatchName", "GlobalJobId", "CpusProvisioned", "GpusProvisioned", "QDate", "JobCurrentStartDate", "RemoteSysCpu", "RemoteUserCpu", "RemoteWallClockTime"]

                        output = call("condor_q", *args)
                        parse_condor_q_output(output)
                    end

                    # Retrieve slot information using `condor_status`
                    # @param owner [String] the owner(s) of the slots
                    # @raise [Error] if `condor_status` command exited unsuccessfully
                    # @return [Array<Hash>] list of details for slots
                    def get_slots
                        args = ["-af", "Machine", "TotalSlotCPUs", "TotalSlotGPUs", "TotalSlotMemory", "CPUs", "GPUs", "Memory", "NumDynamicSlots"]
                        args.concat ["-constraint", "\"DynamicSlot is undefined\""]

                        output = call("condor_status", *args)
                        parse_condor_status_output(output)
                    end


                    # Retrieve accounts using user_group_map on @submit_host
                    # @return [Hash{String => Array<String>}] mapping of usernames to their groups
                    def get_accounts
                        raise Error, "user_group_map is not defined" if user_group_map.nil? || user_group_map.empty?
                        
                        # Retrieve accounts and cache them
                        output = call("cat", user_group_map)
                        accounts = {}
                        output.each_line do |line|
                            next if line.strip.empty? || line.start_with?("#") # Skip empty lines and comments
                            _, username, groups = line.strip.split(/\s+/, 3)
                            accounts[username] = groups.split(",") if username && groups
                        end
                        accounts
                    rescue Error => e
                        raise Error, "Failed to retrieve accounts: #{e.message}"
                    end

                    private

                    # Parse the output of `condor_q` into a list of job hashes
                    def parse_condor_q_output(output)
                        jobs = []
                        output.each_line do |line|
                            # Parse each line into a hash (custom parsing logic for HTCondor)
                            job_data = line.split
                            jobs << { id: job_data[0], status: job_data[1], owner: job_data[2], acct_group: job_data[3], job_name: job_data[4],
                                      submit_host: @submit_host,
                                      procs: job_data[5].to_i, gpus: job_data[6].to_i,
                                      submission_time: Time.at(job_data[7].to_i), dispatch_time: Time.at(job_data[8].to_i),
                                      cpu_time: job_data[9].to_i,
                                      wallclock_time: job_data[10].to_i, native: job_data }
                        end
                        jobs
                    end

                    # Parse the output of `condor_status` into a list of slot hashes
                    def parse_condor_status_output(output)
                        slots = []
                        output.each_line do |line|
                            # Parse each line into a hash (custom parsing logic for HTCondor slots)
                            slot_data = line.split
                            slots << { machine: slot_data[0], total_cpus: slot_data[1].to_i, total_gpus: slot_data[2].to_i, total_memory: slot_data[3].to_i,
                                       cpus: slot_data[4].to_i, gpus: slot_data[5].to_i, memory: slot_data[6].to_i,
                                       num_dynamic_slots: slot_data[7].to_i }
                        end
                        slots
                    end

                    # Call a forked HTCondor command
                    def call(cmd, *args, env: {}, stdin: "")
                        cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
                        args = args.map(&:to_s)
                        
                        cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking)
                        o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s)
                        s.success? ? o : raise(Error, e)
                    end
                end

                # Map HTCondor job statuses to symbols
                STATUS_MAP = {
                    "1" => :queued,
                    "2" => :running,
                    "3" => :running,
                    "4" => :completed,
                    "5" => :queued_held,
                    "6" => :running,
                    "7" => :suspended
                }.freeze

                # @api private
                # @param opts [#to_h] the options defining this adapter
                # @option opts [Batch] :htcondor The HTCondor batch object
                # @see Factory.build_htcondor
                def initialize(opts = {})
                    o = opts.to_h.symbolize_keys

                    @htcondor = o.fetch(:htcondor) { raise ArgumentError, "No HTCondor object specified. Missing argument: htcondor" }
                end

                # Submit a job with the attributes defined in the job template instance
                # @param script [Script] script object that describes the script and
                #   attributes for the submitted job
                # @raise [JobAdapterError] if something goes wrong submitting a job
                # @return [String] the job id returned after successfully submitting a
                #   job
                def submit(script)
                    args = []
                    args.concat ["-batch-name", "#{script.job_name}"] unless script.job_name.nil?
                    args.concat ["-name", "#{script.queue_name}"] unless script.queue_name.nil?
                    args.concat ["-a", "priority=#{script.priority}"] unless script.priority.nil?
                    args.concat ["-a", "accounting_group=#{script.accounting_id}"] unless script.accounting_id.nil?
                    
                    args.concat ["-a", "submit_as_hold=#{script.hold}"] unless script.submit_as_hold.nil?
                    args.concat ["-a", "max_retries=0"] unless !script.rerunnable.nil? && script.rerunnable

                    args.concat ["-a", "allowed_execute_duration=#{script.wall_time}"] unless script.wall_time.nil?
                    args.concat ["-a", "periodic_remove='HoldReasonCode == 47'"] unless script.wall_time.nil?
                    args.concat ["-a", "deferral_time=#{script.start_time.tv_sec}"] unless script.start_time.nil?

                    args.concat ["-a", "request_cpus=#{script.cores}"] unless script.cores.nil?
                    # requesting 1GB of memory per core seems reasonable
                    args.concat ["-a", "request_memory=#{script.cores * 1024}"] unless script.native.include?(:request_memory) && !script.native[:request_memory].nil?
                    args.concat ["-a", "request_gpus=#{script.gpus_per_node}"] unless script.gpus_per_node.nil?

                    universe = script.native[:universe] || @htcondor.default_universe
                    args.concat ["-a", "universe=#{universe}"]
                    container_image = script.native[:docker_image] || @htcondor.default_docker_image
                    if universe == "docker" then
                        args.concat ["-a", "docker_image=#{@htcondor.default_docker_image}"] unless script.native.include?(:docker_image) && !script.native[:docker_image].nil?
                    elsif universe == "container" then
                        script.native.delete(:docker_image) unless !script.native.include?(:docker_image)
                        script.native[:container_image] = container_image
                    end

                    args.concat ["-a", "input=#{script.input_path}"] unless script.input_path.nil?
                    if script.output_path.nil? then args.concat ["-a", "output=output.txt"] else args.concat ["-a", "output=#{script.output_path}"] end
                    if script.error_path.nil? then args.concat ["-a", "error=error.txt"] else args.concat ["-a", "error=#{script.error_path}"] end
                    if script.workdir.nil? then args.concat ["-a", "log=job.log"] else args.concat ["-a", "log=#{script.workdir}/job.log"] end

                    args.concat ["-a", "initialdir=#{script.workdir}"] unless script.workdir.nil?
                    args.concat ["-a", "environment=#{script.job_environment.to_a.map { |k, v| "#{k}=#{v}" }.join(',')}"] unless script.job_environment.nil? || script.job_environment.empty?
                    args.concat ["-a", "getenv=#{script.copy_environment}"] unless script.copy_environment.nil?
                    
                    args.concat ["-a", "should_transfer_files=true"]
                    args.concat ["-a", "+OpenOnDemand=true"]

                    args.concat @htcondor.additional_attributes.to_a.map { |k, v| "-a #{k}=#{v}" } unless @htcondor.additional_attributes.nil? || @htcondor.additional_attributes.empty?
                    args.concat script.native.to_a.map { |k, v| "-a #{k}=#{v}" } unless script.native.nil? || script.native.empty?

                    content = script.content

                    # Set executable to some shell to execute the script
                    if script.shell_path.nil?
                        args.concat ["-a", "executable=/bin/bash"]
                    else
                        args.concat ["-a", "executable=#{script.shell_path}"]
                    end
                    # terse to shut up the output, - to get the script arguments from stdin.
                    args.concat ["-terse", "-", "-queue", "1"]
                    script_args = script.args || []

                    @htcondor.submit_string(args: args, script_args: script_args, script: content)
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Retrieve job info from the resource manager
                # @param id [#to_s] the id of the job
                # @raise [JobAdapterError] if something goes wrong getting job info
                # @return [Info] information describing submitted job
                def info(id)
                    id = id.to_s
                    jobs = @htcondor.get_jobs(id: id)
                    jobs.empty? ? Info.new(id: id, status: :completed) : parse_job_info(jobs.first)
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Retrieve information for all jobs
                # @raise [JobAdapterError] if something goes wrong retrieving job info
                # @return [Array<Info>] list of information describing submitted jobs
                def info_all(attrs: nil)
                    jobs = @htcondor.get_jobs
                    jobs.map { |job| parse_job_info(job) }
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Retrieve the status of a job
                # @param id [#to_s] the id of the job
                # @raise [JobAdapterError] if something goes wrong retrieving the job status
                # @return [Symbol] the status of the job
                def status(id)
                    id = id.to_s
                    jobs = @htcondor.get_jobs(id: id)
                    jobs.empty? ? :completed : get_state(jobs.first[:status])
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Retrieve cluster status information
                # @raise [JobAdapterError] if something goes wrong retrieving cluster status
                # @return [Hash] summary of cluster status including active and total nodes, processors, GPUs, etc.
                def cluster_info
                    slots = @htcondor.get_slots
                    active_nodes = slots.count { |slot| slot[:num_dynamic_slots] > 0 }
                    total_nodes = slots.map { |slot| slot[:machine] }.uniq.count
                    active_processors = slots.sum { |slot| slot[:total_cpus] - slot[:cpus] }
                    total_processors = slots.sum { |slot| slot[:total_cpus] }
                    active_gpus = slots.sum { |slot| slot[:total_gpus] - slot[:gpus] }
                    total_gpus = slots.sum { |slot| slot[:total_gpus] }

                    ClusterInfo.new({
                        active_nodes: active_nodes,
                        total_nodes: total_nodes,
                        active_processors: active_processors,
                        total_processors: total_processors,
                        active_gpus: active_gpus,
                        total_gpus: total_gpus
                    })
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Well, HTCondor does support them, but we dont so far
                def supports_job_arrays?
                    false
                end

                # Place a job on hold
                # @param id [#to_s] the id of the job
                # @raise [JobAdapterError] if something goes wrong placing the job on hold
                def hold(id)
                    @htcondor.hold_job(id)
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Release a job from hold
                # @param id [#to_s] the id of the job
                # @raise [JobAdapterError] if something goes wrong releasing the job
                def release(id)
                    @htcondor.release_job(id)
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end
                # Delete a job
                # @param id [#to_s] the id of the job
                # @raise [JobAdapterError] if something goes wrong deleting the job
                def delete(id)
                    @htcondor.remove_job(id)
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                # Retrieve the relevant groups for the current user
                # @return [Array<AccountInfo>] list of groups for the current user
                def accounts
                    username = Etc.getlogin
                    groups = @htcondor.get_accounts[username]
                    parse_group_into_account_info(groups)
                rescue Batch::Error => e
                    raise JobAdapterError, e.message
                end

                private

                def get_state(st)
                    STATUS_MAP.fetch(st.to_s, :undetermined)
                end

                # Parse hash describing HTCondor job status
                def parse_job_info(job)
                    Info.new(
                        id: job[:id],
                        status: get_state(job[:status]),
                        job_name: job[:job_name],
                        job_owner: job[:owner],
                        accounting_id: job[:acct_group],
                        submit_host: job[:submit_host],
                        procs: job[:procs],
                        gpus: job[:gpus],
                        submission_time: job[:submission_time],
                        dispatch_time: job[:dispatch_time],
                        cpu_time: job[:cpu_time],
                        wallclock_time: job[:wallclock_time],
                        native: job[:native],

                    )
                end

                # Parse group information into AccountInfo objects
                # @param groups [Array<String>] list of group names
                # @return [Array<AccountInfo>] list of AccountInfo objects
                def parse_group_into_account_info(groups)
                    groups.map { |group| AccountInfo.new(name: group, cluster: @htcondor.cluster) }
                end

            end
        end
    end
end
