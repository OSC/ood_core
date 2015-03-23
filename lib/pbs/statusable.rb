module PBS
  module Statusable
    # Get status of job by creating a Query object
    def status(args = {})
      args.merge!({id: id})
      q = Query.new(type: :job, conn: conn)
      q.find(args)
    end
  end
end
