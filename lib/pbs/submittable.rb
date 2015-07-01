require "socket"
require "tempfile"
require "open3"

module PBS
  module Submittable
    HOSTNAME = Socket.gethostname

    def headers
      {
        ATTR[:N] => "Jobname",
        ATTR[:o] => "#{Dir.pwd}/",
        ATTR[:e] => "#{Dir.pwd}/",
        ATTR[:j] => "oe",
      }.merge @headers
    end

    def resources
      {
        nodes: "1:ppn=#{conn.batch_ppn}",
        walltime: "00:10:00",
      }.merge @resources
    end

    def envvars
      {
        PBS_O_WORKDIR: "#{Dir.pwd}",
      }.merge @envvars
    end

    # Can submit a script as a file or string
    # The PBS headers defined in the file will NOT be parsed
    # all PBS headers must be supplied programmatically
    def submit(args = {})
      file = args[:file]
      string = args[:string] || File.open(file).read
      queue = args[:queue]
      qsub = args[:qsub] ? true : false

      @headers = args[:headers] || {}
      @resources = args[:resources] || {}
      @envvars = args[:envvars] || {}

      # Create batch script in tmp file, submit, remove tmp file
      script = Tempfile.new('qsub.')
      begin
        script.write string
        script.close
        if qsub
          _qsub_submit(script.path, queue)
        else
          _pbs_submit(script.path, queue)
        end
      ensure
        script.unlink # deletes the temp file
      end

      self
    end

    # Connect to server, submit job with headers,
    # disconnect, and finally check for errors
    def _pbs_submit(script, queue)
      # Generate attribute hash for this job
      attribs = headers
      attribs[ATTR[:l]] = resources
      attribs[ATTR[:v]] = envvars.map{|k,v| "#{k}=#{v}"}.join(",")

      # Filter some of the attributes
      attribs[ATTR[:o]].prepend("#{HOSTNAME}:")
      attribs[ATTR[:e]].prepend("#{HOSTNAME}:")

      # Submit job
      conn.connect unless conn.connected?
      attropl = Torque::Attropl.from_hash(attribs)
      self.id = Torque.pbs_submit(conn.conn_id, attropl, script, queue, nil)
      conn.disconnect
      Torque.check_for_error
    end

    # Submit using system call `qsub`
    # Note: Do not need to filter as OSC has personal torque filter
    def _qsub_submit(script, queue)
      params = "-q #{queue}@#{conn.batch_server}"
      params << headers.map{|k,v| " -#{ATTR.key(k)} '#{v}'"}.join("")
      params << resources.map{|k,v| " -l '#{k}=#{v}'"}.join("")
      params << " -v '#{envvars.map{|k,v| "#{k}=#{v}"}.join(",")}'"
      cmd = "#{conn.batch_module} && qsub #{params} #{script}"
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        exit_status = wait_thr.value
        if exit_status.success?
          self.id = stdout.read
          self.id.chomp!  # newline character at end of pbsid
        else
          raise PBS::Error, "#{stderr.read}"
        end
      end
    end
  end
end
