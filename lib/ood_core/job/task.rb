module OodCore
  module Job
    class Task
      attr_reader :id
      attr_reader :status

      def initialize(id:, status:, **_)
        @id = id.to_s
        @status = OodCore::Job::Status.new(state: status)
      end

      def to_h
        {
          :id => id,
          :status => status
        }
      end

      def ==(other)
        self.to_h == other.to_h
      end
    end
  end
end