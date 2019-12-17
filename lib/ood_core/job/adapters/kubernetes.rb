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

        require 'ood_core/job/adapters/kubernetes/resources'

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

          resource_yml, id = generate_id_yml(script.native)
          cmd = "#{formatted_ns_cmd} create -f -"

          puts "Submitting:\n#{resource_yml}"

          _, e, s = Open3.capture3(cmd, stdin_data: resource_yml)
          raise Error, e unless s.success?

          id
        rescue => err # TODO: rm after testing
          puts "#{err.backtrace}"
          raise err
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
          pod_json, _, pod_success = json3_ns_cmd('get', 'pod', id)
          return default_info(id) unless pod_success.success? # throw error up the stack instead?

          service_json, = json3_ns_cmd('get', 'service', service_name(id))
          secret_json, = json3_ns_cmd('get', 'secret', secret_name(id))

          info = info_from_json(pod_json: pod_json, service_json: service_json, secret_json: secret_json)
          puts "info is #{info.inspect}"
          info
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
          _, error, pod = Open3.capture3(cmd)

          # just eat the results of deleting services and secrets
          # also can't call json3_ns_cmd bc delete only supports '-o name'
          # and that complicates that functions implementation
          cmd = "#{namespaced_cmd} delete service #{service_name(id)}"
          Open3.capture3(cmd)
          cmd = "#{namespaced_cmd} delete secret #{secret_name(id)}"
          Open3.capture3(cmd)
          cmd = "#{namespaced_cmd} delete configmap #{configmap_name(id)}"
          Open3.capture3(cmd)

          raise error unless pod.success?
        end

        def configmap_mount_path
          '/ood'
        end

        private

        def generate_id_yml(native_data)
          container = container_from_native(native_data)
          id = generate_id(container.name)
          configmap = configmap_from_native(native_data, id)
          init_containers = init_ctrs_from_native(native_data)
          spec = Resources::PodSpec.new(container, init_containers)

          template = ERB.new(File.read(resource_file))

          [template.result(binding), id]
        end

        def json3_ns_cmd(verb, resource, id)
          cmd = "#{formatted_ns_cmd} #{verb} #{resource} #{id}"
          data, error, success = Open3.capture3(cmd)
          data = data.empty? ? '{}' : data
          json_data = JSON.parse(data, symbolize_names: true)

          [json_data, error, success]
        end

        def info_from_json(pod_json: nil, service_json: nil, secret_json: nil)
          pod_hash = pod_json_to_info_hash(pod_json)
          service_hash = service_json_to_info_hash(service_json)
          secret_hash = secret_json_to_info_hash(secret_json)

          # can't just use deep_merge bc we don't depend *directly* on rails
          pod_hash[:native] = pod_hash[:native].merge(service_hash[:native])
          pod_hash[:native] = pod_hash[:native].merge(secret_hash[:native])
          Info.new(pod_hash)
        end

        def service_name(id)
          id + '-service'
        end

        def secret_name(id)
          id + '-secret'
        end

        def configmap_name(id)
          id + '-configmap'
        end

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

        def container_from_native(native)
          container = native.fetch(:container)
          # TODO: throw the right error here telling folks what they
          # need to implement if a fetch KeyError is thrown
          Resources::Container.new(
            container[:name],
            container[:image],
            parse_command(container[:command]),
            container[:port]
          )
        end

        def configmap_from_native(native, id)
          configmap = native.fetch(:configmap, nil)
          return nil if configmap.nil?

          Resources::ConfigMap.new(
            configmap_name(id),
            configmap[:filename],
            configmap[:data]
          )
        end

        def init_ctrs_from_native(native_data)
          init_ctrs = []
          return init_ctrs unless native_data.key?(:init_ctrs)

          ctrs = native_data[:init_ctrs]
          ctrs.each do |ctr_raw|
            ctr = Resources::Container.new(
              ctr_raw[:name],
              ctr_raw[:image],
              ctr_raw[:command].to_a
            )
            init_ctrs.push(ctr)
          end

          init_ctrs
        end

        def parse_command(cmd)
          command = cmd&.split(' ')
          command.nil? ? [] : command
        end

        def pod_json_to_info_hash(json_data)
          return {} if json_data.nil?

          # passing json_data around like it's OK, probably should check for nil?
          id = json_data.dig(:metadata, :name).to_s
          {
            id: id,
            job_name: name_from_metadata(json_data.dig(:metadata)),
            status: pod_json_to_status(json_data),
            job_owner: json_data.dig(:metadata, :namespace).to_s,
            submission_time: submission_time(json_data),
            dispatch_time: dispatch_time(json_data),
            wallclock_time: wallclock_time(json_data),
            native: {
              host: json_data.dig(:status, :hostIP)
            }
          }
        end

        def service_json_to_info_hash(json_data)
          # .spec.ports[0].nodePort
          ports = json_data.dig(:spec, :ports)
          {
            native:
              {
                port: ports[0].dig(:nodePort)
              }
          }
        rescue # bc you never know!
          empty_native
        end

        def secret_json_to_info_hash(json_data)
          return empty_native if json_data.nil?

          raw = json_data.dig(:data, :password)
          return empty_native if raw.nil?
          {
            native:
              {
                password: Base64.decode64(raw)
              }
          }
        end

        def empty_native
          {
            native: {}
          }
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
          return nil if start_time.nil?

          et = end_time(status, state_data)

          et.nil? ? nil : et - start_time
        end

        def end_time(status, state_data)
          if status == 'completed'
            end_time_string = state_data.dig(:terminated, :finishedAt)
            et = DateTime.parse(end_time_string).to_time.to_i
          elsif status == 'running'
            et = DateTime.now.to_time.to_i
          else
            et = nil
          end

          et
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
            hash = pod_json_to_info_hash(pod)
            info = Info.new(hash)
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
