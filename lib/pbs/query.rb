module PBS
  class Query
    attr_reader :type
    attr_reader :conn
    attr_accessor :where_procs

    STATTYPE = {job: :pbs_statjob, queue: :pbs_statque,
                node: :pbs_statnode, server: :pbs_statserver}

    # Needs a connection object and a query type
    # Query types: :job, :queue, :server, :node
    def initialize(args = {})
      @conn = args[:conn] || Conn.new
      @type = args[:type] || :job
      @where_procs = []
    end

    # Boolean procs used to filter out query results
    # Examples:
    #   where {|h| h[PBS::ATTR[:N]] == "SimpleJob"}
    #   where(PBS::ATTR[:N]) {|v| v == "SimpleJob"}
    #   where
    # the last one is used with other methods
    # i.e., where.not(PBS::ATTR[:N]) => "SimpleJob")
    def where(arg = nil, &block)
      relation = self.clone
      relation.where_procs = @where_procs.clone
      relation.where_procs << (arg ? Proc.new {|h| block.call(h[arg])} : block)
      relation
    end

    # Used to filter where key attrib is equal to value
    #   where.is(PBS::ATTR[:N] => "SimpleJob")
   def is(hash)
      key, value = hash.first
      raise PBS::Error, "`where' method not called before" unless where_procs[-1]
      self.where_procs[-1] = Proc.new {|h| h[key] == value}
      self
    end

    # Used to filter where key attrib is NOT equal to value
    #   where.not(PBS::ATTR[:N] => "SimpleJob")
    def not(hash)
      key, value = hash.first
      raise PBS::Error, "`where' method not called before" unless where_procs[-1]
      self.where_procs[-1] = Proc.new {|h| h[key] != value}
      self
    end

    # Used to filter specific user
    #   where.user("username")
    def user(name)
      self.where_procs[-1] = Proc.new {|h| /^#{name}@/ =~ h[ATTR[:owner]]}
      raise PBS::Error, "`where' method not called before" unless where_procs[-1]
      self
    end

    def find(args = {})
      id = args[:id] || nil
      filters = args[:filters]
      filters = [args[:filter]] if args[:filter]

      # Get array of batch status hashes
      batch_list = _pbs_batchstat(id, filters)

      # Further filter results and then output them
      _filter_where_values(batch_list)
    end

    # Filter an array of hashes based on the defined where procs
    # Comparisons are done inside the :attribs hash only
    def _filter_where_values(array)
      array.select do |hash|
        pass = true
        where_procs.each do |p|
          pass = false unless p.call(hash[:attribs])
        end
        pass
      end
    end

    # Connect, get status on batch server,
    # disconnect, parse output, and finally check for errors
    # Don't forget to free up memory the C-library creates
    def _pbs_batchstat(id, filters)
      # Generate attribute list from filter list
      attrib_list = PBS::Torque::Attrl.from_list(filters) if filters

      batch_status = nil
      conn.connect unless conn.connected?
      if type == :server
        batch_status = Torque.send(STATTYPE[type], conn.conn_id, attrib_list, nil)
      else
        batch_status = Torque.send(STATTYPE[type], conn.conn_id, id, attrib_list, nil)
      end
      conn.disconnect
      batch_list = batch_status.to_a
      Torque.pbs_statfree(batch_status)
      Torque.check_for_error
      batch_list
    end
  end
end
