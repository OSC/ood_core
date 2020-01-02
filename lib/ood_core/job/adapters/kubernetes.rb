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
        require 'ood_core/job/adapters/kubernetes/helper'

        using Refinements::ArrayExtensions
        using Refinements::HashExtensions

        def initialize(options = {})
          opts = options.to_h.symbolize_keys

          @config_file = opts.fetch(:config_file, default_config_file)
          @bin = opts.fetch(:bin, '/usr/bin/kubectl')
          @restart_policy = opts.fetch(:restart_policy, 'Never')
          @cluster_name = opts.fetch(:cluster_name, 'open-ondemand')

          @using_context = false
          @using_token = false

          make_kubectl_config(opts)

          @helper = Kubernetes::Helper.new
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
          pod_json, _, pod_success = json3_ns_cmd('get', 'pod', id)
          return default_info(id) unless pod_success.success? # throw error up the stack instead?

          service_json, = json3_ns_cmd('get', 'service', service_name(id))
          secret_json, = json3_ns_cmd('get', 'secret', secret_name(id))

          @helper.info_from_json(pod_json: pod_json, service_json: service_json, secret_json: secret_json)
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

        def username
          @username = Etc.getlogin if @username.nil?
          @username
        end

        def run_as_user
          Etc.getpwnam(username).uid
        end

        def run_as_group
          Etc.getpwnam(username).gid
        end

        def fs_group
          run_as_group
        end

        # helper to template resource yml you're going to submit and
        # create an id.
        def generate_id_yml(native_data)
          container = @helper.container_from_native(native_data)
          id = generate_id(container.name)
          configmap = @helper.configmap_from_native(native_data, id)
          init_containers = @helper.init_ctrs_from_native(native_data)
          spec = Resources::PodSpec.new(container, init_containers)

          template = ERB.new(File.read(resource_file))

          [template.result(binding), id]
        end

        # helper to call kubectl and get json data back.
        # verb, resrouce and id are the kubernetes parlance terms.
        # example: 'kubectl get pod my-pod-id' is verb=get, resource=pod
        # and  id=my-pod-id
        def json3_ns_cmd(verb, resource, id)
          cmd = "#{formatted_ns_cmd} #{verb} #{resource} #{id}"
          data, error, success = Open3.capture3(cmd)
          data = data.empty? ? '{}' : data
          json_data = JSON.parse(data, symbolize_names: true)

          [json_data, error, success]
        end

        def service_name(id)
          @helper.service_name(id)
        end

        def secret_name(id)
          @helper.secret_name(id)
        end

        def configmap_name(id)
          @helper.configmap_name(id)
        end

        def default_info(id)
          Info.new(
            id: id,
            status: Status.new(state: 'completed')
          )
        end

        def namespace
          default_namespace
        end

        def default_namespace
          username
        end

        def context
          @cluster_name
        end

        def default_config_file
          (ENV['KUBECONFIG'] || "#{Dir.home}/.kube/config")
        end

        def default_auth
          {
            type: 'managaged'
          }.symbolize_keys
        end

        def default_server
          {
            endpoint: 'https://localhost:8080',
            cert_authority_file: nil
          }.symbolize_keys
        end

        def formatted_ns_cmd
          "#{namespaced_cmd} -o json"
        end

        def namespaced_cmd
          "#{base_cmd} --namespace=#{namespace}"
        end

        def base_cmd
          base = "#{@bin} --kubeconfig=#{@config_file}"
          base << " --context=#{context}" if @using_context
          base << " --token=#{token}" if @using_token
          base
        end

        def all_pods_to_info(data)
          json_data = JSON.parse(data, symbolize_names: true)
          pods = json_data.dig(:items)

          info_array = []
          pods.each do |pod|
            hash = @helper.pod_info_from_json(pod)
            info = Info.new(hash)
            info_array.push(info)
          end

          info_array
        end

        def make_kubectl_config(config)
          set_cluster(config.fetch(:server, default_server).to_h.symbolize_keys)
          configure_auth(config.fetch(:auth, default_auth).to_h.symbolize_keys)
        end

        def configure_auth(auth)
          type = auth.fetch(:type)
          return if managed?(type)

          case type
          when 'gke'
            set_gke_config(auth)
          when 'oidc'
            set_context
            use_context
            use_token
          end
        end

        def use_context
          @using_context = true
        end

        def use_token
          @using_token = true
        end

        def token
          ENV['HTTP_OIDC_ACCESS_TOKEN'] || 'access_token_not_provided'
        end

        def managed?(type)
          if type.nil?
            true # maybe should be false?
          else
            type.to_s == 'managed'
          end
        end

        def ood_username
          "ood-#{username}"
        end

        def set_gke_config(auth)
          cred_file = auth.fetch(:svc_acct_file)

          cmd = "gcloud auth activate-service-account --key-file=#{cred_file}"
          call(cmd)

          set_gke_credentials(auth)
        end

        def set_gke_credentials(auth)

          zone = auth.fetch(:zone, nil)
          region = auth.fetch(:region, nil)

          locale = ''
          locale = "--zone=#{zone}" unless zone.nil?
          locale = "--region=#{region}" unless region.nil?

          # gke cluster name can probably can differ from what ood calls the cluster
          cmd = "gcloud container clusters get-credentials #{locale} #{@cluster_name}"
          env = { 'KUBECONFIG' => @config_file }
          call(cmd, env)
        end

        def set_context
          cmd = "#{base_cmd} config set-context #{@cluster_name}"
          cmd << " --cluster=#{@cluster_name} --namespace=#{namespace}"
          cmd << " --user=#{ood_username}"

          call(cmd)
        end

        def set_cluster(config)
          server = config.fetch(:endpoint)
          cert = config.fetch(:cert_authority_file)

          cmd = "#{base_cmd} config set-cluster #{@cluster_name}"
          cmd << " --server=#{server}"
          cmd << " --certificate-authority=#{cert}" unless cert.nil?

          call(cmd)
        end

        def call(cmd = '', env = {})
          _, error, s = Open3.capture3(env, cmd)
          raise error unless s.success?
        end

      end
      # end kubernetes class (above)
    end
  end
end
