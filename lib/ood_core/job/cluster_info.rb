module OodCore
  module Job
    # An object that contains details about the cluster's active and total nodes, processors, and gpu nodes
    class ClusterInfo
      using Refinements::HashExtensions

      attr_reader :active_nodes, :total_nodes, :active_processors, :total_processors, :active_gpu_nodes,
                  :total_gpu_nodes

      def initialize(opts = {})
        opts = opts.transform_keys(&:to_sym)
        @active_nodes        = opts.fetch(:active_nodes, nil).to_i
        @total_nodes         = opts.fetch(:total_nodes, nil).to_i
        @active_processors   = opts.fetch(:active_processors, nil).to_i
        @total_processors    = opts.fetch(:total_processors, nil).to_i
        @active_gpu_nodes    = opts.fetch(:active_gpu_nodes, nil).to_i
        @total_gpu_nodes     = opts.fetch(:total_gpu_nodes, nil).to_i
      end

      def to_h
        {
          active_nodes: active_nodes,
          total_nodes: total_nodes,
          active_processors: active_processors,
          total_processors: total_processors,
          active_gpu_nodes: active_gpu_nodes,
          total_gpu_nodes: total_gpu_nodes
        }
      end
    end
  end
end
