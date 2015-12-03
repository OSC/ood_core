module PBS
  module Statusable
    # Get status of job by creating a Query object
    def status(args = {})
      q = Query.new(type: :job, conn: conn)
      q.find(args.merge(id: id))[0]
    end
  end
end
