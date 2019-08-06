require "time"
require "ood_core/refinements/hash_extensions"
require "ood_core/refinements/array_extensions"
require "ood_core/job/adapters/helper"
require "json"
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
      def self.build_openstack(config)
        Adapters::Openstack.new(**config)
      end
    end

    module Adapters
      # An adapter object that describes the communication with a Slurm
      # resource manager for job management.
      class Openstack < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions

        # The path to the client installation binaries
        # @return [Pathname] path to binaries
        attr_reader :bin

        # Optional overrides for client executables
        # @return Hash<String, String>
        attr_reader :bin_overrides

        attr_reader :token, :api_base_uri

        # @param bin [#to_s] path to slurm installation binaries
        def initialize(api_base_uri: nil, token: nil, bin: nil, bin_overrides: {})
          @api_base_uri = api_base_uri
          @token   = token
          @bin     = Pathname.new(bin.to_s)
          @bin_overrides = bin_overrides
        end

        # Call a forked Slurm command for a given cluster
        # def call(cmd, *args, env: {}, stdin: "")
        #   cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
        #   args  = args.map(&:to_s)
        #   args += ["-M", cluster] if cluster
        #   env = env.to_h
        #   env["SLURM_CONF"] = conf.to_s if conf
        #
        #   o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s)
        #   s.success? ? o : raise(Error, e)
        # end


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

          # TODO
        end

        # Retrieve list of all servers from the OpenStack instance
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Array<Info>] information describing submitted jobs
        # @see Adapter#info_all
        def info_all(attrs: nil)
          cmd = "get_servers"
          cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
          env = { "TOKEN" => token, "BASE_URI" => api_base_uri}
          args = []

          o, e, s = Open3.capture3(env, cmd, *args)
          if s.success?
            #puts o
   	        o = o.split("\n")
	          serversHash = JSON.parse(o[0])
	          #puts serversHash
            servers = serversHash["servers"]
            servers.each do |server|
		          puts server["name"]
	          end 
          else
           raise(JobAdapterError, e)
          end
        end

        # Retrieve job info from the resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job info
        # @return [Info] information describing submitted job
        # @see Adapter#info
        def info(id)

          # TODO: return Info for existing VM
          # or Info.new(id: id, status: :completed) for invalid job id (i.e. completed/done/destroyed)
          # or raise JobAdapterError if some other error
        end
        def flavors_all
	    cmd = "get_flavors.sh"
            cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
            env = { "TOKEN" => token, "BASE_URI" => api_base_uri}
            args = []
 
            o, e, s = Open3.capture3(env, cmd, *args)
            if s.success?
              #puts o
              o = o.split("\n")
             flavorsHash = JSON.parse(o[0])
              #puts serversHash
              flavors = flavorsHash["flavors"]
              flavors.each do |flavor|
                 puts flavor["name"]
              end
            else
              raise(JobAdapterError, e)
            end
	 end
        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong getting job status
        # @return [Status] status of job
        # @see Adapter#status
        def image_all
            cmd = "get_images.sh"
            cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
            env = { "TOKEN" => token, "BASE_URI" => api_base_uri}
            args = []
 
            o, e, s = Open3.capture3(env, cmd, *args)
            if s.success?
              #puts o
              o = o.split("\n")
              imagesHash = JSON.parse(o[0])
              #puts serversHash
              images = imagessHash["images"]
              images.each do |image|
                 puts image["name"]
              end
            else
              raise(JobAdapterError, e)
            end
        end
        
        def status(id)
          info(id).status
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong holding a job
        # @return [void]
        # @see Adapter#hold
        def hold(id)
          # TODO
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong releasing a job
        # @return [void]
        # @see Adapter#release
        def release(id)
          # TODO
        end

        # Delete the submitted job
        # @param id [#to_s] the id of the job
        # @raise [JobAdapterError] if something goes wrong deleting a job
        # @return [void]
        # @see Adapter#delete
        def delete(id)
          # TODO
        end
      end
    end
  end
end
