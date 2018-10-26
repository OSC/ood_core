require "ood_core/refinements/array_extensions"
require "ood_core/refinements/hash_extensions"
require "rexml/document"


module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      # Build the Sun Grid Engine adapter from a configuration
      # @param config [#to_h] the configuration for job adapter
      # @option config [Object] :cluster (nil) The cluster to communicate with
      # @option config [Object] :conf (nil) Path to the SGE conf
      # @option config [Object] :bin (nil) Path to SGE client binaries
      def self.build_sge(config)
        # c = config.to_h.symbolize_keys
        # cluster = c.fetch(:cluster, nil)
        # conf    = c.fetch(:conf, nil)
        # bin     = c.fetch(:bin, nil)
        # Adapters::Sge.new(cluster: cluster, conf: conf, bin: bin)
        batch = Adapters::Sge::Batch.new(config.to_h.symbolize_keys)
        Adapters::Sge.new(batch: batch)
      end
    end

    module Adapters
      class Sge < Adapter
        using Refinements::HashExtensions
        using Refinements::ArrayExtensions

        require "ood_core/job/adapters/sge/batch"

        # The cluster of the Sun Grid Engine batch server
        # @example CHPC's kingspeak cluster
        #   my_batch.cluster #=> "kingspeak"
        # @return [String, nil] the cluster name
        attr_reader :cluster

        # The path to the Sun Grid Engine configuration file
        # @example For Sun Grid Engine 10.0.0
        #   my_batch.conf.to_s #=> "/etc/gridengine/configuration
        # @return [Pathname, nil] path to gridengine conf
        attr_reader :conf

        # The path to the Sun Grid Engine client installation binaries
        # @example For Sun Grid Engine 10.0.0
        #   my_batch.bin.to_s #=> "/usr/local/slurm/10.0.0/bin
        # @return [Pathname] path to slurm binaries
        attr_reader :bin

        # The root exception class that all Sun Grid Engine-specific exceptions inherit
        # from
        class Error < StandardError; end

        # @param cluster [#to_s, nil] the cluster name
        # @param conf [#to_s, nil] path to the slurm conf
        # @param bin [#to_s] path to slurm installation binaries
        def initialize(batch:)
          @batch = batch
        end

        # Submit a job with the attributes defined in the job template instance
        # @abstract Subclass is expected to implement {#submit}
        # @raise [NotImplementedError] if subclass did not define {#submit}
        # @example Submit job template to cluster
        #   solver_id = job_adapter.submit(solver_script)
        #   #=> "1234.server"
        # @example Submit job that depends on previous job
        #   post_id = job_adapter.submit(
        #     post_script,
        #     afterok: solver_id
        #   )
        #   #=> "1235.server"
        # @param script [Script] script object that describes the
        #   script and attributes for the submitted job
        # @param after [#to_s, Array<#to_s>] this job may be scheduled for execution
        #   at any point after dependent jobs have started execution
        # @param afterok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with no errors
        # @param afternotok [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution only after dependent jobs have terminated with errors
        # @param afterany [#to_s, Array<#to_s>] this job may be scheduled for
        #   execution after dependent jobs have terminated
        # @return [String] the job id returned after successfully submitting a job
        def submit(script, after: [], afterok: [], afternotok: [], afterany: [])
          # SGE supports jod dependencies on job completion
          # ignoring after, afterok, afternotok
          afterany   = Array(afterany).map(&:to_s)
          args = []
          args += ['-h'] unless script.submit_as_hold.nil?
          args += ['-r', 'yes'] unless script.rerunnable.nil?
          script.job_environment.each_pair {|k, v| args += ['-v', "#{k.to_s}=#{v.to_s}"]}
          args += ['-wd', script.workdir] unless script.workdir.nil?
          args += ['-M', script.email.first] unless (script.email.nil? || script.email_on_terminated.nil?)
          args += ['-m', 'ea'] unless (script.email.nil? || script.email_on_terminated.nil?)

          # TODO handle afterany dependencies

          # ignoring email_on_started
          args += ['-N', script.job_name]
          # These aren't supportable in SGE 6.4
          # @param shell_path [#to_s, nil] file path specifying login shell
          # @param error_path [#to_s, nil] file path specifying error stream
          # @param input_path [#to_s, nil] file path specifying input stream
          args += ['-e', script.error_path] unless script.error_path.nil?
          args += ['-o', script.output_path] unless script.output_path.nil?
          args += ['-ar', script.reservation_id] unless script.reservation_id.nil?
          args += ['-q', script.queue_name] unless script.queue_name.nil?
          args += ['-p', script.priority] unless script.priority.nil?
          args += ['-a', script.start_time.strftime('%C%y%m%d%H%M.%S')] unless script.start_time.nil?
          args += ['-l', "h_rt=" + seconds_to_duration(script.wall_time)] unless script.wall_time.nil?
          args += ['-P', script.accounting_id] unless script.accounting_id.nil?
          # @param native [Object, nil] native specifications

          @batch.submit(script.content, args)
        end

        # Convert seconds to duration
        def seconds_to_duration(time)
            "%02d:%02d:%02d" % [time/3600, time/60%60, time%60]
        end

        # Retrieve info for all jobs from the resource manager
        # @abstract Subclass is expected to implement {#info_all}
        # @raise [NotImplementedError] if subclass did not define {#info_all}
        # @return [Array<Info>] information describing submitted jobs
        def info_all
          # raise NotImplementedError, "subclass did not define #info_all"
          @batch.get_all
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner)
          owner = Array.wrap(owner).map(&:to_s).join(',')
          @batch.get_all(owner: owner)
        end

        # Retrieve job info from the resource manager
        # @abstract Subclass is expected to implement {#info}
        # @param id [#to_s] the id of the job
        # @return [Info] information describing submitted job
        def info(id)
          job_info = @batch.get_info_historical_job(id)
          return job_info unless job_info.nil?

          @batch.get_info_enqueued_job(id)
        end

        # Retrieve job status from resource manager
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id)
          info(id).status
        end

        # Put the submitted job on hold
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id)
          @batch.hold(id)
        end

        # Release the job that is on hold
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id)
          @batch.release(id)
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          @batch.del(id)
        end
      end
    end
  end
end