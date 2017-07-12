require "yaml"

module OodCore
  # An enumerable that contains a list of {Cluster} objects
  class Clusters
    include Enumerable

    # The format version of the configuration file
    CONFIG_VERSION = %w( v2 )

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
          CONFIG_VERSION.any? do |version|
            YAML.safe_load(config.read).fetch(version, {}).each do |k, v|
              clusters << Cluster.new(send("parse_#{version}", id: k, cluster: v))
            end
            !clusters.empty?
          end
        elsif config.directory?
          Pathname.glob(config.join("*.yml")).each do |p|
            CONFIG_VERSION.any? do |version|
              if cluster = YAML.safe_load(p.read).fetch(version, nil)
                clusters << Cluster.new(send("parse_#{version}", id: p.basename(".yml").to_s, cluster: cluster))
                true
              else
                false
              end
            end
          end
        else
          raise ConfigurationNotFound, "configuration file '#{config}' does not exist"
        end

        new clusters
      end

      private
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
