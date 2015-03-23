require "socket"
require "tempfile"

module PBS
  module Submittable
    HOSTNAME = Socket.gethostname

    DEFAULT_HEADERS = {
      Torque::ATTR[:N] => "Jobname",
      Torque::ATTR[:o] => "#{Dir.pwd}/",
      Torque::ATTR[:e] => "#{Dir.pwd}/",
      Torque::ATTR[:j] => "oe",
    }

    DEFAULT_RESOURCES = {
      nodes: "1:ppn=1",
      walltime: "00:10:00"
    }

    DEFAULT_ENVVARS = {
      PBS_O_WORKDIR: "#{Dir.pwd}"
    }

    # Can submit a script as a file or string
    # The PBS headers defined in the file will NOT be parsed
    # all PBS headers must be supplied programmatically
    def submit(args = {})
      file = args[:file]
      string = args[:string] || File.open(file).read
      queue = args[:queue]
      headers = DEFAULT_HEADERS.merge(args[:headers] || {})
      resources = DEFAULT_RESOURCES.merge(args[:resources] || {})
      envvars = DEFAULT_ENVVARS.merge(args[:envvars] || {})

      # Generate attribute hash for this job
      attribs = headers
      attribs[Torque::ATTR[:l]] = resources
      attribs[Torque::ATTR[:v]] = envvars.map{|k,v| "#{k}=#{v}"}.join(",")

      # Clean up some of the attributes
      attribs[Torque::ATTR[:o]].prepend("#{HOSTNAME}:")
      attribs[Torque::ATTR[:e]].prepend("#{HOSTNAME}:")

      # Create batch script in tmp file, submit, remove tmp file
      script = Tempfile.new('qsub.')
      begin
        script.write string
        script.close
        _pbs_submit(attribs, script.path, queue)
      ensure
        script.unlink # deletes the temp file
      end

      self
    end

    # Connect to server, submit job with headers,
    # disconnect, and finally check for errors
    def _pbs_submit(attribs, script, queue)
      conn.connect unless conn.connected?
      attropl = Torque::Attropl.from_hash(attribs)
      self.id = Torque.pbs_submit(conn.conn_id, attropl, script, queue, nil)
      conn.disconnect
      Torque.check_for_error
    end
  end
end
