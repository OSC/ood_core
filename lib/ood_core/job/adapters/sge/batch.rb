# Patch to allow runtime setting of the libdrmaa path
module FFI_DRMAA
  def self.libdrmaa_path
    @libdrmaa_path || 'libdrmaa.so'
  end
  
  def self.libdrmaa_path=(path)
    @libdrmaa_path = path
  end
end

# Object used for simplified communication with a SGE batch server
#
# @api private
class OodCore::Job::Adapters::Sge::Batch
  using OodCore::Refinements::HashExtensions

  attr_reader :bin, :bin_overrides, :conf, :cluster, :helper, :submit_host, :strict_host_checking
  
  require "ood_core/job/adapters/sge/qstat_xml_j_r_listener"
  require "ood_core/job/adapters/sge/qstat_xml_r_listener"
  require "ood_core/job/adapters/sge/helper"
  require "ood_core/job/adapters/helper"
  require 'time'


  class Error < StandardError; end

  # @param opts [#to_h] the options defining this adapter
  # @option opts [Batch] :batch The Sge batch object
  #
  # @api private
  # @see Factory.build_sge
  def initialize(config)
    @cluster          = config.fetch(:cluster, nil)
    @bin              = Pathname.new(config.fetch(:bin, nil).to_s)
    @sge_root         = Pathname.new(config[:sge_root] || ENV['SGE_ROOT'] || "/var/lib/gridengine")
    @bin_overrides    = config.fetch(:bin_overrides, {})
    @submit_host      = config.fetch(:submit_host, "")
    @strict_host_checking = config.fetch(:strict_host_checking, true)

    # FIXME: hack as this affects env of the process!
    ENV['SGE_ROOT'] = @sge_root.to_s

    if config[:libdrmaa_path]
      load_drmaa(config[:libdrmaa_path])
      @can_use_drmaa    = true
    else
      @can_use_drmaa    = false
    end

    @helper = OodCore::Job::Adapters::Sge::Helper.new
  end

  def load_drmaa(libdrmaa_path)
    FFI_DRMAA.libdrmaa_path = libdrmaa_path if libdrmaa_path
    require "ood_core/job/adapters/drmaa"
    require "ood_core/refinements/drmaa_extensions"
  end

  # Get OodCore::Job::Info for every enqueued job, optionally filtering on owner
  # @param owner [#to_s] the owner or owner list
  # @return [Array<OodCore::Job::Info>]
  def get_all(owner: nil)
    listener = QstatXmlRListener.new
    argv = ['qstat', '-r', '-xml']
    argv.concat ['-u', owner] unless owner.nil?
    REXML::Parsers::StreamParser.new(call(*argv), listener).parse

    listener.parsed_jobs.map{
      |job_hash| OodCore::Job::Info.new(
        **post_process_qstat_job_hash(job_hash)
      )
    }
  end

  # Get OodCore::Job::Info for a job_id that may still be in the queue
  # 
  # If libdrmaa is not loaded then we cannot use DRMAA. Using DRMAA provides
  # better job status and should always be chosen if it is possible.
  # 
  # When qstat is called in XML mode for a job id that is not in the queue
  # invalid XML is returned. The second line of the invalid XML contains the
  # string '<unknown_jobs' which will be used to recognize this case.
  # 
  # @param job_id [#to_s]
  # @return [OodCore::Job::Info]
  def get_info_enqueued_job(job_id)
    job_info = OodCore::Job::Info.new(id: job_id.to_s, status: :completed)
    argv = ['qstat', '-r', '-xml', '-j', job_id.to_s]

    begin
      results = call(*argv)
      listener = QstatXmlJRListener.new
      REXML::Parsers::StreamParser.new(results, listener).parse

      job_hash = listener.parsed_job

      if job_hash[:id]
        update_job_hash_status!(job_hash)
      else
        job_hash[:id] = job_id
        job_hash[:status] = :completed
      end

      job_info = OodCore::Job::Info.new(**job_hash)
    rescue REXML::ParseException => e
      # If the error is something other than a job not being found by qstat re-raise the error
      unless results =~ /unknown_jobs/
        raise e, "REXML::ParseException error and command '#{argv.join(' ')}' produced results that didn't contain string 'unknown_jobs'. ParseException: #{e.message}"
      end
    rescue StandardError => e
      # Note that DRMAA is not guaranteed to be defined, hence the tests
      raise e unless ( can_use_drmaa? && e.is_a?(DRMAA::DRMAAInvalidJobError))  # raised when job is not found
    end

    job_info
  end

  def update_job_hash_status!(job_hash)
    if get_status_from_drmaa?(job_hash)
      begin
        job_hash[:status] = get_status_from_drmma(job_hash[:id])
      rescue DRMAA::DRMAAException => e
        # log DRMAA error?
      end
    end
  end

  def get_status_from_drmaa?(job_hash)
    # DRMAA does not recognize the parent task in job arrays
    # e.g. 123 is invalid if it is an array job, while 123.4 is valid
    can_use_drmaa? && job_hash[:tasks].empty?
  end

  def can_use_drmaa?
    @can_use_drmaa
  end

  # Call qhold
  # @param job_id [#to_s]
  # @return [void]
  def hold(job_id)
    call('qhold', job_id)
  end

  # Call qrls
  # @param job_id [#to_s]
  # @return [void]
  def release(job_id)
    call('qrls', job_id)
  end

  # Call qdel
  # @param job_id [#to_s]
  # @return [void]
  def delete(job_id)
    call('qdel', job_id)
  end

  # Call qsub with arguments and the scripts content
  # @param job_id [#to_s]
  # @return job_id [String]
  def submit(content, args)
      @helper.parse_job_id_from_qsub(call('qsub', *args, :stdin => content))
  end

  # Call a forked SGE command for a given batch server
  def call(cmd, *args, env: {}, stdin: "", chdir: nil)
    cmd = OodCore::Job::Adapters::Helper.bin_path(cmd, bin, bin_overrides)
    env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
    cmd, args = OodCore::Job::Adapters::Helper.ssh_wrap(submit_host, cmd, args, strict_host_checking, env)
    chdir ||= "."
    o, e, s = Open3.capture3(env, cmd, *(args.map(&:to_s)), stdin_data: stdin.to_s, chdir: chdir.to_s)
    s.success? ? o : raise(Error, e)
  end

  # Adapted from http://www.softpanorama.org/HPC/Grid_engine/Queues/queue_states.shtml
  STATE_MAP = {
    'EhRqw'   => :undetermined, # all pending states with error
    'Ehqw'    => :undetermined, # all pending states with error
    'Eqw'     => :undetermined, # all pending states with error
    'RS'      => :suspended,    # all suspended with re-submit
    'RT'      => :suspended,    # all suspended with re-submit
    'Rr'      => :running,      # running, re-submit
    'Rs'      => :suspended,    # all suspended with re-submit
    'Rt'      => :running,      # transferring, re-submit
    'RtS'     => :suspended,    # all suspended with re-submit
    'RtT'     => :suspended,    # all suspended with re-submit
    'Rts'     => :suspended,    # all suspended with re-submit
    'S'       => :suspended,    # queue suspended
    'T'       => :suspended,    # queue suspended by alarm
    'dRS'     => :completed,    # all running and suspended states with deletion
    'dRT'     => :completed,    # all running and suspended states with deletion
    'dRr'     => :completed,    # all running and suspended states with deletion
    'dRs'     => :completed,    # all running and suspended states with deletion
    'dRt'     => :completed,    # all running and suspended states with deletion
    'dS'      => :completed,    # all running and suspended states with deletion
    'dT'      => :completed,    # all running and suspended states with deletion
    'dr'      => :completed,    # all running and suspended states with deletion
    'ds'      => :completed,    # all running and suspended states with deletion
    'dt'      => :completed,    # all running and suspended states with deletion
    'hRwq'    => :queued_held,  # pending, system hold, re-queue
    'hqw'     => :queued_held,  # pending, system hold
    'qw'      => :queued,       # pending
    'r'       => :running,      # running
    's'       => :suspended,    # suspended
    't'       => :running,      # transferring
    'tS'      => :suspended,    # queue suspended
    'tT'      => :suspended,    # queue suspended by alarm
    'ts'      => :suspended,    # obsuspended
  }

  def translate_sge_state(sge_state_code)
    STATE_MAP.fetch(sge_state_code, :undetermined)
  end

  def translate_drmaa_state(drmaa_state_code)
    DRMAA::DRMMA_TO_OOD_STATE_MAP.fetch(drmaa_state_code, :undetermined)
  end

  def post_process_qstat_job_hash(job_hash)
    # dispatch is not set if the job is not running
    if ! job_hash.key?(:wallclock_time)
      job_hash[:wallclock_time] = job_hash.key?(:dispatch_time) ? Time.now.to_i - job_hash[:dispatch_time] : 0
    end

    job_hash[:status] = translate_sge_state(job_hash[:status])
    update_job_hash_status!(job_hash)

    job_hash
  end

  # Get the job status using DRMAA
  def get_status_from_drmma(job_id)
    translate_drmaa_state(DRMAA::SessionSingleton.instance.job_ps(job_id.to_s))
  end
end
