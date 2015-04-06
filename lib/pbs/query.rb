module PBS
  class Query
    attr_reader :type
    attr_reader :conn
    attr_accessor :where_values, :wherenot_values

    STATTYPE = {job: :pbs_statjob, queue: :pbs_statque,
                node: :pbs_statnode, server: :pbs_statserver}

    # Needs a connection object and a query type
    # Query types: :job, :queue, :server, :node
    def initialize(args = {})
      @conn = args[:conn] || Conn.new
      @type = args[:type] || :job
      @where_values = {}
      @wherenot_values = {}
    end

    # Add hash where value to further filter results
    %w(where wherenot).each do |action|
      define_method(action) do |where_value|
        relation = self.clone
        relation.where_values = where_values.clone
        relation.wherenot_values = wherenot_values.clone
        relation.send("#{action.to_s + '_values'}".to_sym).merge!(where_value)
        relation
      end
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

    # Filter an array of hashes based on the defined
    # where values
    # Comparisons are done inside the :attribs hash only
    def _filter_where_values(array)
      array.select do |hash|
        pass = true
        attribs = hash[:attribs]

        # Exact filter on each attribute type
        where_values.each do |k,v|
          if attribs.has_key?(k)
            pass = false unless attribs[k] == v
          end
        end
        wherenot_values.each do |k,v|
          if attribs.has_key?(k)
            pass = false if attribs[k] == v
          end
        end

        # Special filters
        ###################

        # :user filter
        if where_values.has_key?(:user)
          pass = false unless /#{where_values[:user]}@/ =~ attribs[ATTR[:owner]]
        end
        if wherenot_values.has_key?(:user)
          pass = false if /#{where_values[:user]}@/ =~ attribs[ATTR[:owner]]
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
