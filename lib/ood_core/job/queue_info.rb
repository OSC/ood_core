module OodCore
  module Job

    class QueueInfo

      attr_reader :name

      attr_reader :qos

      # nil means ALL accounts are allowed.
      attr_reader :allow_accounts

      
      attr_reader :deny_accounts
  
      def initialize(**opts)
        @name = opts.fetch(:name, 'unknown')
        @qos = opts.fetch(:qos, [])
        @allow_accounts = opts.fetch(:allow_accounts, nil)
        @deny_accounts = opts.fetch(:denied_accounts, [])
      end
  
  
      def to_h
        instance_variables.map do |var|
          name = var.to_s.gsub('@', '').to_sym
          [name, send(name)]
        end.to_h
      end
    end
  end
end