require "yaml"

module OodCore
  # An enumerable that contains a list of {Cluster} objects
  class Clusters
    include Enumerable

    # The format version of the configuration file
    CONFIG_VERSION = ['v2', 'v1']

    class << self
      # Parse a configuration file or a set of configuration files in a
      # directory
      # @param path [#to_s] configuration file or directory path
      # @raise [ConfigurationNotFound] if path does not exist
      # @return [Clusters] the clusters parsed from config
      def load_file(path)
        config = Pathname.new(path.to_s).expand_path

        clusters = []
        if config.file?
          if config.readable?
            CONFIG_VERSION.any? do |version|
              begin
                YAML.safe_load(config.read)&.fetch(version, {}).each do |k, v|
                  clusters << Cluster.new(send("parse_#{version}", id: k, cluster: v))
                end
              rescue Psych::SyntaxError => e
                clusters << InvalidCluster.new(
                  id: config.basename(config.extname).to_s,
                  errors: [ e.message.to_s ]
                )
              end
            end
          end
        elsif config.directory?
          Pathname.glob([config.join("*.yml"), config.join("*.yaml")]).select(&:file?).select(&:readable?).each do |p|
            CONFIG_VERSION.any? do |version|
              begin
                if cluster = YAML.safe_load(p.read)&.fetch(version, nil)
                  clusters << Cluster.new(send("parse_#{version}", id: p.basename(p.extname()).to_s, cluster: cluster))
                end
              rescue Psych::SyntaxError => e
                clusters << InvalidCluster.new(
                  id: p.basename(p.extname).to_s,
                  errors: [ e.message.to_s ]
                )
              end
            end
          end
        else
          raise ConfigurationNotFound, "configuration file '#{config}' does not exist"
        end

        new clusters
      end

      private
        # Parse a list of clusters from a 'v1' config
        # NB: Makes minimum assumptions about config
        def parse_v1(id:, cluster:)
          c = {
            id: id,
            metadata: {},
            login: {},
            job: {},
            acls: [],
            custom: {}
          }

          c[:metadata][:title]   = cluster["title"] if cluster.key?("title")
          c[:metadata][:url]     = cluster["url"]   if cluster.key?("url")
          c[:metadata][:private] = true             if cluster["cluster"]["data"]["hpc_cluster"] == false

          if l = cluster["cluster"]["data"]["servers"]["login"]
            c[:login][:host] = l["data"]["host"]
          end

          if rm = cluster["cluster"]["data"]["servers"]["resource_mgr"]
            c[:job][:adapter] = "torque"
            c[:job][:host]    = rm["data"]["host"]
            c[:job][:lib]     = rm["data"]["lib"]
            c[:job][:bin]     = rm["data"]["bin"]
            c[:job][:acls]    = []
          end

          if v = cluster["validators"]
            if vc = v["cluster"]
              c[:acls] = vc.map do |h|
                {
                  adapter: "group",
                  groups: h["data"]["groups"],
                  type: h["data"]["allow"] ? "whitelist" : "blacklist"
                }
              end
            end
          end

          c
        end

        # Parse a list of clusters from a 'v2' config
        def parse_v2(id:, cluster:)
          cluster.merge(id: id)
        end
    end

    # @param clusters [Array<Cluster>] list of cluster objects
    def initialize(clusters = [])
      @clusters = clusters
    end

    # Find cluster in list using the id of the cluster
    # @param id [Object] id of cluster object
    # @return [Cluster, nil] cluster object if found
    def [](id)
      @clusters.detect { |cluster| cluster == id }
    end

    # For a block {|cluster| ...}
    # @yield [cluster] Gives the next cluster object in the list
    def each(&block)
      @clusters.each(&block)
    end
  end
end
