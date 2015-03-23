module PBS
  class Job
    attr_accessor :id
    attr_reader :conn

    include Submittable
    include Statusable
    include Holdable
    include Deletable

    # Needs a connection object and headers
    # Examples of headers found in 'headers.rb'
    def initialize(args = {})
      # Job specific args
      @id = args[:id]
      @conn = args[:conn] || Conn.new
    end

  end
end
