module OodCore
  module Job
    class Factory
      using Refinements::HashExtensions

      def self.build_kubernetes(config)
        Adapters::Kubernetes.new(config)
      end

    end

    module Adapters
      # A class that handles the communication with a resource manager for
      # submitting/statusing/holding/deleting jobs
      # @abstract
      class Kubernetes < Adapter

        require 'ood_core/job/adapters/kubernetes/container'

        using Refinements::ArrayExtensions
        using Refinements::HashExtensions

        def initialize(options = {})
          opts = options.to_h.symbolize_keys

          @config = opts.fetch(:config, '')
          @bin = opts.fetch(:bin, '')
          @volumes = opts.fetch(:volumes, [])
          @restart_policy = opts.fetch(:restart_policy, 'Never')
        end

        def resource_file(resource_type = 'pod')
          File.dirname(__FILE__) + "/kubernetes/templates/#{resource_type}.yml.erb"
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
          raise ArgumentError, 'Must specify the script' if script.nil?

          container = native_to_container(script.native)
          id = generate_id(container.name)
          template = ERB.new(File.read(resource_file))
          resource_yml = template.result(binding)

          cmd = "#{formatted_ns_cmd} create -f -"

          puts "Submitting:\n#{resource_yml}"

          _, e, s = Open3.capture3(cmd, stdin_data: resource_yml)
          raise Error, e unless s.success?

          id
        end

        def generate_id(name)
          # 2_821_109_907_456 = 36**8
          name.downcase.tr(' ', '-') + '-' + rand(2_821_109_907_456).to_s(36)
        end

        # Retrieve info for all jobs from the resource manager
        # @abstract Subclass is expected to implement {#info_all}
        # @raise [NotImplementedError] if subclass did not define {#info_all}
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @return [Array<Info>] information describing submitted jobs
        def info_all(attrs: nil)
          cmd = "#{base_cmd} get pods -o json --all-namespaces"
          output, error, s = Open3.capture3(cmd)
          raise error unless s.success?

          all_pods_to_info(output)
        end

        # Retrieve info for all jobs for a given owner or owners from the
        # resource manager
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @return [Array<Info>] information describing submitted jobs
        def info_where_owner(owner, attrs: nil)
          owner = Array.wrap(owner).map(&:to_s)

          # must at least have job_owner to filter by job_owner
          attrs = Array.wrap(attrs) | [:job_owner] unless attrs.nil?

          info_all(attrs: attrs).select { |info| owner.include? info.job_owner }
        end

        # Iterate over each job Info object
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_all_each(attrs: nil)
          return to_enum(:info_all_each, attrs: attrs) unless block_given?

          info_all(attrs: attrs).each do |job|
            yield job
          end
        end

        # Iterate over each job Info object
        # @param owner [#to_s, Array<#to_s>] the owner(s) of the jobs
        # @param attrs [Array<symbol>] defaults to nil (and all attrs are provided) 
        #   This array specifies only attrs you want, in addition to id and status.
        #   If an array, the Info object that is returned to you is not guarenteed
        #   to have a value for any attr besides the ones specified and id and status.
        #
        #   For certain adapters this may speed up the response since
        #   adapters can get by without populating the entire Info object
        # @yield [Info] of each job to block
        # @return [Enumerator] if no block given
        def info_where_owner_each(owner, attrs: nil)
          return to_enum(:info_where_owner_each, owner, attrs: attrs) unless block_given?

          info_where_owner(owner, attrs: attrs).each do |job|
            yield job
          end
        end

        # Whether the adapter supports job arrays
        # @return [Boolean] - assumes true; but can be overridden by adapters that
        #   explicitly do not
        def supports_job_arrays?
          false
        end

        # Retrieve job info from the resource manager
        # @abstract Subclass is expected to implement {#info}
        # @raise [NotImplementedError] if subclass did not define {#info}
        # @param id [#to_s] the id of the job
        # @return [Info] information describing submitted job
        def info(id)
          puts "getting info for #{id}"
          cmd = "#{formatted_ns_cmd} get pod #{id}"
          output, _, s = Open3.capture3(cmd)
          return default_info(id) unless s.success? # throw error up the stack instead?

          json_data = JSON.parse(output, symbolize_names: true)
          pod_json_to_info(json_data)

        end

        # Retrieve job status from resource manager
        # @note Optimized slightly over retrieving complete job information from server
        # @abstract Subclass is expected to implement {#status}
        # @raise [NotImplementedError] if subclass did not define {#status}
        # @param id [#to_s] the id of the job
        # @return [Status] status of job
        def status(id)
          info(id).status
        end

        # Put the submitted job on hold
        # @abstract Subclass is expected to implement {#hold}
        # @raise [NotImplementedError] if subclass did not define {#hold}
        # @param id [#to_s] the id of the job
        # @return [void]
        def hold(id)
          raise NotImplementedError, 'subclass did not define #hold'
        end

        # Release the job that is on hold
        # @abstract Subclass is expected to implement {#release}
        # @raise [NotImplementedError] if subclass did not define {#release}
        # @param id [#to_s] the id of the job
        # @return [void]
        def release(id)
          raise NotImplementedError, 'subclass did not define #release'
        end

        # Delete the submitted job
        # @abstract Subclass is expected to implement {#delete}
        # @raise [NotImplementedError] if subclass did not define {#delete}
        # @param id [#to_s] the id of the job
        # @return [void]
        def delete(id)
          cmd = "#{namespaced_cmd} delete pod #{id}"
          _, error, s = Open3.capture3(cmd)
          raise error unless s.success?
        end

        private

        def default_info(id)
          Info.new(
            id: id,
            status: Status.new(state: 'completed')
          )
        end

        def default_namespace
          ENV['USER'].to_s
        end

        def formatted_ns_cmd(namespace = default_namespace)
          "#{namespaced_cmd(namespace)} -o json"
        end

        def namespaced_cmd(namespace = default_namespace)
          "#{base_cmd} --namespace=#{namespace}"
        end

        def base_cmd
          "#{@bin} --kubeconfig #{@config}"
        end

        def native_to_container(native)
          container = native.fetch(:container)
          OodCore::Job::Adapters::Kubernetes::Container.new(
            container[:name],
            container[:image],
            parse_command(container[:command]),
            container[:port]
          )
        end

        def parse_command(cmd)
          cmd&.split(' ')
        end

        def pod_json_to_info(json_data)
          # passing json_data around like it's OK, probably should check for nil?
          Info.new(
            id: json_data.dig(:metadata, :name).to_s,
            job_name: name_from_metadata(json_data.dig(:metadata)),
            status: pod_json_to_status(json_data),
            job_owner: json_data.dig(:metadata, :namespace).to_s,
            submission_time: submission_time(json_data),
            dispatch_time: dispatch_time(json_data),
            wallclock_time: wallclock_time(json_data)
          )
        end

        def dispatch_time(json_data)
          status = pod_json_to_status(json_data)
          state_data = json_data.dig(:status, :containerStatuses)[0].dig(:state)
          date_string = nil

          if status == 'completed'
            date_string = state_data.dig(:terminated, :startedAt)
          elsif status == 'running'
            date_string = state_data.dig(:running, :startedAt)
          end

          date_string.nil? ? nil : DateTime.parse(date_string).to_time.to_i
        end

        def wallclock_time(json_data)
          status = pod_json_to_status(json_data)
          state_data = json_data.dig(:status, :containerStatuses)[0].dig(:state)
          start_time = dispatch_time(json_data)
          puts "wallclock_time for #{json_data.dig(:metadata, :name)}"
          return nil if start_time.nil?

          end_time = nil

          if status == 'completed'
            end_time_string = state_data.dig(:terminated, :finishedAt)
            end_time = DateTime.parse(end_time_string).to_time.to_i
          elsif status == 'running'
            end_time = DateTime.now.to_time.to_i
          else
            end_time = nil
          end

          end_time.nil? ? nil : end_time - start_time
        end

        def end_time(json_data)
          json_data.dig(:status, :status.startTime)
        end

        def submission_time(json_data)
          str = json_data.dig(:status, :startTime)
          DateTime.parse(str).to_time.to_i
        end

        def name_from_metadata(metadata)
          name = metadata.dig(:labels, :'app.kubernetes.io/name')
          name = metadata.dig(:labels, :'k8s-app') if name.nil?
          name = metadata.dig(:name) if name.nil? # pod-id but better than nil?
          name
        end

        def all_pods_to_info(data)
          json_data = JSON.parse(data, symbolize_names: true)
          pods = json_data.dig(:items)

          info_array = []
          pods.each do |pod|
            info = pod_json_to_info(pod)
            info_array.push(info)
            puts "added info for #{info.inspect}"
          end

          info_array
        end

        def pod_json_to_status(json_data)
          container_statuses = json_data.dig(:status, :containerStatuses)
          json_state = container_statuses[0].dig(:state) # only support 1 container/pod

          state = 'undetermined'
          state = 'running' unless json_state.dig(:running).nil?
          state = 'completed' unless json_state.dig(:terminated).nil?
          state = 'queued' unless json_state.dig(:waiting).nil?

          Status.new(state: state)
        end
      end

    end
  end
end
