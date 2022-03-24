module OodCore
  module Job
    # An object that contains details about the cluster's active and total nodes, processors, and gpu nodes
    class ClusterInfo
      attr_reader :cluster, :nodes_active, :nodes_total, :processors_active, :processors_total, :gpu_nodes_active,
                  :gpu_nodes_total

      def initialize(cluster_name: nil, nodes_active: nil, nodes_total: nil, processors_active: nil, processors_total: nil,
                     gpu_nodes_active: nil, gpu_nodes_total: nil, **_)
        @cluster_name        = cluster
        @nodes_active        = nodes_active
        @nodes_total         = nodes_total
        @processors_active   = processors_active
        @processors_total    = processors_total
        @gpu_nodes_active    = gpu_nodes_active
        @gpu_nodes_total     = gpu_nodes_total
      end

      def to_h
        {
          nodes_active: nodes_active,
          nodes_total: nodes_total,
          processors_active: processors_active,
          processors_total: processors_total,
          gpu_nodes_active: gpu_nodes_active,
          gpu_nodes_total: gpu_nodes_total
        }
      end
    end
  end
end
