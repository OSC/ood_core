require "socket"
require "tempfile"
require "open3"

module PBS
  module Submittable
    HOSTNAME = Socket.gethostname

    # Can submit a script as a file or string
    # The PBS headers defined in the file will NOT be parsed
    # all PBS headers must be supplied programmatically
    def submit(args)
      string = args.fetch(:string) { File.open(args[:file]).read }
      queue  = args.fetch(:queue, nil)
      qsub   = args.fetch(:qsub, true)

      headers   = _get_headers   args.fetch(:headers,   {})
      resources = _get_resources args.fetch(:resources, {})
      envvars   = _get_envvars   args.fetch(:envvars,   {})

      # Create batch script in tmp file, submit, remove tmp file
      script = Tempfile.new('qsub.')
      begin
        script.write string
        script.close
        if qsub
          _qsub_submit(script.path, queue, headers, resources, envvars)
        else
          _pbs_submit(script.path, queue, headers, resources, envvars)
        end
      ensure
        script.unlink # deletes the temp file
      end

      self
    end

    # Connect to server, submit job with headers,
    # disconnect, and finally check for errors
    def _pbs_submit(script, queue, headers, resources, envvars)
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
    def _qsub_submit(script, queue, headers, resources, envvars)
      params = "-q #{queue}@#{conn.server}"
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
      cmd = "#{conn.module} && qsub #{params} #{script}"
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        exit_status = wait_thr.value
        unless exit_status.success?
          raise PBS::Error, "#{stderr.read}"
        end

        self.id = stdout.read.chomp   # newline char at end of job id
      end
    end

    # Hash representing the job headers
    def _get_headers(headers)
      {
        ATTR[:N] => "Jobname",
        ATTR[:o] => "#{Dir.pwd}/",
        ATTR[:e] => "#{Dir.pwd}/",
        ATTR[:S] => "/bin/bash",
      }.merge headers
    end

    # Hash representing the resources used
    def _get_resources(resources)
      {
        walltime: "01:00:00",
      }.merge resources
    end

    # Hash representing the PBS working directory
    def _get_envvars(envvars)
      {
        PBS_O_WORKDIR: "#{Dir.pwd}",
      }.merge envvars
    end
  end
end
