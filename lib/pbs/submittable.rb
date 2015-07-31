require "socket"
require "tempfile"
require "open3"

module PBS
  module Submittable
    HOSTNAME = Socket.gethostname

    # Returns a Hash representing the job headers
    # 
    #   Includes:
    #     <tt>:Job_Name</tt> Job Name
    #     <tt>:Output_Path</tt> Output Path
    #     <tt>:Error_Path</tt> Error Path
    #     <tt>:Join_Path</tt> Merged standard error stream and standard output stream of the job.
    def headers
      {
        ATTR[:N] => "Jobname",
        ATTR[:o] => "#{Dir.pwd}/",
        ATTR[:e] => "#{Dir.pwd}/",
        ATTR[:j] => "oe",
      }.merge @headers
    end

    # Returns a Hash representing the resources used
    #   
    #   Includes:
    #     <tt>nodes</tt> Number of nodes (Default: 1)
    #                     Number of processors
    #     <tt>walltime</tt> Wall Time (Default: 00:10:00)
    def resources
      {
        nodes: "1:ppn=#{conn.batch_ppn}",
        walltime: "00:10:00",
      }.merge @resources
    end

    # Returns a Hash representing the PBS working directory
    # 
    #   Includes:
    #     <tt>PBS_O_WORKDIR</tt> The PBS working directory
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
      params << resources.map{|k,v| " -l '#{k}=#{v}'"}.join("")
      params << " -v '#{envvars.map{|k,v| "#{k}=#{v}"}.join(",")}'"
      params << headers.map do |k,v|
        param = ATTR.key(k)
        if param && param.length == 1
          " -#{param} '#{v}'"
        else
          " -W '#{k}=#{v}'"
        end
      end.join("")
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
