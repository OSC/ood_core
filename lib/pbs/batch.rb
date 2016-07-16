require 'open3'

module PBS
  # Object used for simplified communication with a batch server
  class Batch
    # The host of the Torque batch server
    # @example OSC's Oakley batch server
    #   my_conn.host #=> "oak-batch.osc.edu"
    # @return [String] the batch server host
    attr_reader :host

    # The path to the Torque client installation
    # @example For Torque 5.0.0
    #   my_conn.prefix.to_s #=> "/usr/local/torque/5.0.0"
    # @return [Pathname, nil] path to torque installation
    attr_reader :prefix

    # @param host [#to_s] the batch server host
    # @param prefix [#to_s, nil] path to torque installation
    def initialize(host:, prefix: nil, **_)
      @host    = host.to_s
      @prefix  = Pathname.new(prefix) if prefix
    end

    # Convert object to hash
    # @return [Hash] the hash describing this object
    def to_h
      {host: host, prefix: prefix}
    end

    # The comparison operator
    # @param other [#to_h] batch server to compare against
    # @return [Boolean] how batch servers compare
    def ==(other)
      to_h == other.to_h
    end

    # Checks whether two batch server objects are completely identical to each
    # other
    # @param other [Batch] batch server to compare against
    # @return [Boolean] whether same objects
    def eql?(other)
      self.class == other.class && self == other
    end

    # Generates a hash value for this object
    # @return [Fixnum] hash value of object
    def hash
      [self.class, to_h].hash
    end

    # Creates a connection to batch server and calls block in context of this
    # connection
    # @yieldparam cid [Fixnum] connection id from established batch server connection
    # @yieldreturn the final value of the block
    def connect(&block)
      Torque.lib = prefix ? prefix.join('lib', 'libtorque.so') : nil
      cid = Torque.pbs_connect(host)
      Torque.raise_error(cid.abs) if cid < 0  # raise error if negative connection id
      begin
        value = yield cid
      ensure
        Torque.pbs_disconnect(cid)            # always close connection
      end
      Torque.check_for_error                  # check for errors at end
      value
    end

    # Get a hash with status info for this batch server
    # @example Status info for OSC Oakley batch server
    #   my_conn.get_status
    #   #=>
    #   #{
    #   #  :name => "oak-batch.osc.edu:15001",
    #   #  :attribs => {
    #   #    :server_state => "Idle",
    #   #    ...
    #   #  }
    #   #}
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Hash] status info for batch server
    def get_status(filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list filters
        batch_status = Torque.pbs_statserver cid, filters, nil
        batch_status.to_a.first.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get a list of hashes of the queues on the batch server
    # @example Status info for OSC Oakley queues
    #   my_conn.get_queues
    #   #=>
    #   #[
    #   #  {
    #   #    :name => "parallel",
    #   #    :attribs => {
    #   #      :queue_type => "Execution",
    #   #      ...
    #   #    }
    #   #  },
    #   #  {
    #   #    :name => "serial",
    #   #    :attribs => {
    #   #      :queue_type => "Execution",
    #   #      ...
    #   #    }
    #   #  },
    #   #  ...
    #   #]
    # @param id [#to_s] the id of requested information
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Array<Hash>] list of status infos for the various queues
    def get_queues(id: '', filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list(filters)
        batch_status = Torque.pbs_statque cid, id.to_s, filters, nil
        batch_status.to_a.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get info for given batch server's queue
    # @example Status info for OSC Oakley's parallel queue
    #   my_conn.get_queue("parallel")
    #   #=>
    #   #{
    #   #  :name => "parallel",
    #   #  :attribs => {
    #   #    :queue_type => "Execution",
    #   #    ...
    #   #  }
    #   #}
    # @param id [#to_s] the id of the queue
    # @param (see @get_queues)
    # @return [Hash] status info for the queue
    def get_queue(id, **kwargs)
      get_queues(id: id, **kwargs).first
    end


    # Get a list of hashes of the nodes on the batch server
    # @example Status info for OSC Oakley nodes
    #   my_conn.get_nodes
    #   #=>
    #   #[
    #   #  {
    #   #    :name => "n0001",
    #   #    :attribs => {
    #   #      :np => "12",
    #   #      ...
    #   #    }
    #   #  },
    #   #  {
    #   #    :name => "n0002",
    #   #    :attribs => {
    #   #      :np => "12",
    #   #      ...
    #   #    }
    #   #  },
    #   #  ...
    #   #]
    # @param id [#to_s] the id of requested information
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Array<Hash>] list of status infos for the various nodes
    def get_nodes(id: '', filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list(filters)
        batch_status = Torque.pbs_statnode cid, id.to_s, filters, nil
        batch_status.to_a.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get info for given batch server's node
    # @example Status info for OSC Oakley's 'n0001' node
    #   my_conn.get_node('n0001')
    #   #=>
    #   #{
    #   #  :name => "n0001",
    #   #  :attribs => {
    #   #    :np => "12",
    #   #    ...
    #   #  }
    #   #}
    # @param id [#to_s] the id of the node
    # @param (see #get_nodes)
    # @return [Hash] status info for the node
    def get_node(id, **kwargs)
      get_nodes(id: id, **kwargs).first
    end

    # Get a list of hashes of the jobs on the batch server
    # @example Status info for OSC Oakley jobs
    #   my_conn.get_jobs
    #   #=>
    #   #[
    #   #  {
    #   #    :name => "10219837.oak-batch.osc.edu",
    #   #    :attribs => {
    #   #      :Job_Owner => "bob@oakley02.osc.edu",
    #   #      :Job_Name => "CFD_Solver",
    #   #      ...
    #   #    }
    #   #  },
    #   #  {
    #   #    :name => "10219838.oak-batch.osc.edu",
    #   #    :attribs => {
    #   #      :Job_Owner => "sally@oakley01.osc.edu",
    #   #      :Job_Name => "FEA_Solver",
    #   #      ...
    #   #    }
    #   #  },
    #   #  ...
    #   #]
    # @param id [#to_s] the id of requested information
    # @param filters [Array<Symbol>] list of attribs to filter on
    # @return [Array<Hash>] list of status infos for the various jobs
    def get_jobs(id: '', filters: [])
      connect do |cid|
        filters = PBS::Torque::Attrl.from_list(filters)
        batch_status = Torque.pbs_statjob cid, id.to_s, filters, nil
        batch_status.to_a.tap { Torque.pbs_statfree batch_status }
      end
    end

    # Get info for given batch server's job
    # @example Status info for OSC Oakley's '10219837.oak-batch.osc.edu' job
    #   my_conn.get_job('102719837.oak-batch.osc.edu')
    #   #=>
    #   #{
    #   #  :name => "10219837.oak-batch.osc.edu",
    #   #  :attribs => {
    #   #    :Job_Owner => "bob@oakley02.osc.edu",
    #   #    :Job_Name => "CFD_Solver",
    #   #    ...
    #   #  }
    #   #}
    # @param id [#to_s] the id of the job
    # @param (see #get_jobs)
    # @return [Hash] status info for the job
    def get_job(id, **kwargs)
      get_jobs(id: id, **kwargs).first
    end

    # Put specified job on hold
    # Possible hold types:
    #   :u => Available to the owner of the job, the batch operator and the batch administrator
    #   :o => Available to the batch operator and the batch administrator
    #   :s => Available to the batch administrator
    # @example Put job '10219837.oak-batch.osc.edu' on hold
    #   my_conn.hold_job('10219837.oak-batch.osc.edu')
    # @param id [#to_s] the id of the job
    # @param type [Symbol] type of hold to be applied
    # @return [void]
    def hold_job(id, type: :u)
      connect do |cid|
        Torque.pbs_holdjob cid, id.to_s, type.to_s, nil
      end
    end

    # Release a specified job that is on hold
    # Possible hold types:
    #   :u => Available to the owner of the job, the batch operator and the batch administrator
    #   :o => Available to the batch operator and the batch administrator
    #   :s => Available to the batch administrator
    # @example Release job '10219837.oak-batch.osc.edu' from hold
    #   my_conn.release_job('10219837.oak-batch.osc.edu')
    # @param id [#to_s] the id of the job
    # @param type [Symbol] type of hold to be removed
    # @return [void]
    def release_job(id, type: :u)
      connect do |cid|
        Torque.pbs_rlsjob cid, id.to_s, type.to_s, nil
      end
    end

    # Delete a specified job from batch server
    # @example Delete job '10219837.oak-batch.osc.edu' from batch
    #   my_conn.delete_job('10219837.oak-batch.osc.edu')
    # @param id [#to_s] the id of the job
    # @return [void]
    def delete_job(id)
      connect do |cid|
        Torque.pbs_deljob cid, id.to_s, nil
      end
    end

    # Submit a script to the batch server
    # @param script [#to_s] path to the script
    # @param queue [#to_s] queue to submit script to
    # @param headers [Hash] pbs headers
    # @param resources [Hash] pbs resources
    # @param envvars [Hash] pbs environment variables
    # @param qsub [Boolean] whether use library or binary for submission
    # @return [String] the id of the job that was created
    def submit_script(script, queue: nil, headers: {}, resources: {}, envvars: {}, qsub: true)
      send(qsub ? :qsub_submit : :pbs_submit, script, queue, headers, resources, envvars)
    end

    # Submit a script expanded into a string to the batch server
    # @param string [#to_s] script as a string
    # @param (see #submit_script)
    # @return [String] the id of the job that was created
    def submit_string(string, **kwargs)
      Tempfile.open('qsub.') do |f|
        f.write string.to_s
        f.close
        submit_script(f.path, **kwargs)
      end
    end

    private
      # Submit a script using Torque library
      def pbs_submit(script, queue, headers, resources, envvars)
        attribs = headers.dup
        attribs[ATTR[:l]] = resources.dup unless resources.empty?
        attribs[ATTR[:v]] = envvars.map{|k,v| "#{k}=#{v}"}.join(",") unless envvars.empty?

        connect do |cid|
          attropl = Torque::Attropl.from_hash attribs
          Torque.pbs_submit cid, attropl, script.to_s, queue.to_s, nil
        end
      end

      # Submit a script using Torque binary
      # NB: The binary includes many useful filters and is preferred
      def qsub_submit(script, queue, headers, resources, envvars)
        params  = ["-q", "#{queue}@#{host}"]
        params += resources.map{|k,v| ["-l", "#{k}=#{v}"]}.flatten unless resources.empty?
        params += ["-v", envvars.map{|k,v| "#{k}=#{v}"}.join(",")] unless envvars.empty?
        params += headers.map do |k,v|
          if param = ATTR.key(k) and param.length == 1
            ["-#{param}", "#{v}"]
          else
            ["-W", "#{k}=#{v}"]
          end
        end.flatten
        params << script.to_s

        o, e, s = Open3.capture3(prefix.join("bin", "qsub").to_s, *params)
        raise PBS::Error, e unless s.success?
        o.chomp
      end
  end
end
