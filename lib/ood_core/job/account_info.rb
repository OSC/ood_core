module OodCore
  module Job

    class AccountInfo

      include OodCore::DataFormatter

      # The name of the account.
      attr_reader :name
      alias to_s name

      # The QoS values this account can use.
      attr_reader :qos

      # The cluster this account is associated with.
      attr_reader :cluster

      def initialize(**opts)
        orig_name = opts.fetch(:name, 'unknown')
        @name = upcase_accounts? ? orig_name.upcase : orig_name
        @qos = opts.fetch(:qos, [])
        @cluster = opts.fetch(:cluster, nil)
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
