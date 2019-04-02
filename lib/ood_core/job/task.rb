module OodCore
  module Job
    class Task
      attr_reader :id, :status, :wallclock_time

      def initialize(id:, status:, wallclock_time: nil, **_)
        @id = id.to_s
        @status = OodCore::Job::Status.new(state: status)
        @wallclock_time = wallclock_time && wallclock_time.to_i
      end

      def to_h
        {
          :id => id,
          :status => status,
          :wallclock_time => wallclock_time
        }
      end

      def ==(other)
        self.to_h == other.to_h
      end
    end
  end
end