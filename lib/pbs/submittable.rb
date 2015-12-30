require "socket"
require "tempfile"
require "open3"

module PBS
  module Submittable
    HOSTNAME = Socket.gethostname

    # Can submit a script as a file or string
    # @param args [Hash] The options when submitting a job.
    # @option args [String] :string The batch script as a string.
    # @option args [String] :file The batch script file if a string is not supplied.
    # @option args [Boolean] :qsub (true) Whether the <tt>qsub</tt> command is used from command line.
    # @option args [Hash] :headers ({}) PBS headers.
    # @option args [Hash] :resources ({}) PBS resources.
    # @option args [Hash] :envvars ({}) PBS environment variables.
    # @raise [Error] if fail to submit batch job.
    def submit(args)
      string = args.fetch(:string) { File.open(args[:file]).read }
      queue  = args.fetch(:queue, nil)
      qsub   = args.fetch(:qsub, true)

      headers   = args.fetch(:headers,   {})
      resources = args.fetch(:resources, {})
      envvars   = args.fetch(:envvars,   {})

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
      attribs = _default_headers.merge(headers)
      attribs[ATTR[:l]] = _default_resources.merge(resources)
      attribs[ATTR[:v]] = _default_envvars.merge(envvars).map{|k,v| "#{k}=#{v}"}.join(",")

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
      params << " -v '#{envvars.map{|k,v| "#{k}=#{v}"}.join(",")}'" unless envvars.empty?
      params << headers.map do |k,v|
        param = ATTR.key(k)
        if param && param.length == 1
          " -#{param} '#{v}'"
        else
          " -W '#{k}=#{v}'"
        end
      end.join("")
      cmd = "#{conn.qsub} #{params} #{script}"
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        exit_status = wait_thr.value
        unless exit_status.success?
          raise PBS::Error, "#{stderr.read}"
        end

        self.id = stdout.read.chomp   # newline char at end of job id
      end
    end

    # Hash representing the job headers
    def _default_headers
      {
        ATTR[:N] => "Jobname",
        ATTR[:o] => "#{Dir.pwd}/",
        ATTR[:e] => "#{Dir.pwd}/",
        ATTR[:S] => "/bin/bash",
      }
    end

    # Hash representing the resources used
    def _default_resources
      {
        walltime: "01:00:00",
      }
    end

    # Hash representing the PBS working directory
    def _default_envvars
      {
        PBS_O_WORKDIR: "#{Dir.pwd}",
      }
    end
  end
end
