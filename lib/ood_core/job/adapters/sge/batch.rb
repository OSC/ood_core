# Object used for simplified communication with a SGE batch server
#
# @api private
class OodCore::Job::Adapters::Sge::Batch
  using OodCore::Refinements::HashExtensions
  require "ood_core/job/adapters/sge/qstat_xml_f_r_listener"
  require "ood_core/job/adapters/sge/helper"
  require "ood_core/refinements/hash_extensions"
  require "ood_core/job/adapters/drmaa"
  require "tempfile"
  require 'time'
  require 'singleton'

  class Error < StandardError; end

  # The one and only connection with DRMAA
  # Attempting to instantiate a DRMAA::Session more than once causes it to crash
  class SessionSingleton < DRMAA::Session
    include Singleton
  end

  # @param opts [#to_h] the options defining this adapter
  # @option opts [Batch] :batch The Sge batch object
  #
  # @api private
  # @see Factory.build_sge
  def initialize(config)
    @cluster          = config.fetch(:cluster, nil)
    @conf             = Pathname.new(config.fetch(:conf, nil))
    @begin            = Pathname.new(config.fetch(:bin, nil))
    @sge_root         = config.key?(:sge_root) && config[:sge_root] ? Pathname.new(config[:sge_root]) : nil
    @ld_library_path  = config.key?(:sge_root) && config[:sge_root] ? Pathname.new(config[:sge_root]) : nil

    @helper = OodCore::Job::Adapters::Sge::Helper.new
  end

  # Get OodCore::Job::Info for every enqueued job, optionally filtering on owner
  # @param owner [#to_s] the owner or owner list
  # @return [Array<OodCore::Job::Info>]
  def get_all(owner: nil)
    listener = QstatXmlFrListener.new
    argv = ['qstat', '-r', '-xml']
    argv += ['-u', owner] unless owner.nil?
    parser = REXML::Parsers::StreamParser.new(call(*argv), listener)
    parser.parse

    listener.parsed_jobs.map{|job_hash| OodCore::Job::Info.new(**post_process_qstat_job_hash(job_hash))}
  end

  # Get OodCore::Job::Info for a job_id that may still be in the queue
  # It is not ideal to load everything just to get the output of a single job,
  # but SGE's qstat does not give a way to get the status of an enqueued job
  # with qstat -j $jobid
  #
  # @param job_id [#to_s]
  # @return [OodCore::Job::Info]
  def get_info_enqueued_job(job_id)
    job_info = OodCore::Job::Info.new(id: job_id, status: :completed)
    if @sge_root.nil?
      found_job = get_all.find{|job_info| job_info.id == job_id.to_s}
      job_info = found_job unless found_job.nil?
    else
      begin
        job_hash = @helper.parse_qstat_output(call('qstat', '-r', '-j', job_id.to_s))
        job_info = post_process_qstat_j_job_hash(
          job_hash,
          get_status_from_drmma(job_id)
        ) if job_hash.key?(:job_number)
      rescue Error
      end
    end

    job_info
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
      cmd = ['qsub'] + args
      @helper.parse_job_id_from_qsub(call(*cmd, :stdin => content))
  end

  # Call a forked SGE command for a given batch server
  def call(cmd, *args, env: {}, stdin: "", chdir: nil)
    cmd = cmd.to_s
    cmd = @bin.join(cmd).to_s if @bin
    args = args.map(&:to_s)
    env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
    chdir ||= "."
    o, e, s = Open3.capture3(env, cmd, *args, stdin_data: stdin.to_s, chdir: chdir.to_s)
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

  DRMMA_TO_OOD_STATE_MAP = {
    DRMAA::STATE_UNDETERMINED          => :undetermined,
    DRMAA::STATE_QUEUED_ACTIVE         => :queued,
    DRMAA::STATE_SYSTEM_ON_HOLD        => :queued_held,
    DRMAA::STATE_USER_ON_HOLD          => :queued_held,
    DRMAA::STATE_USER_SYSTEM_ON_HOLD   => :queued_held,
    DRMAA::STATE_RUNNING               => :running,
    DRMAA::STATE_SYSTEM_SUSPENDED      => :suspended,
    DRMAA::STATE_USER_SUSPENDED        => :suspended,
    DRMAA::STATE_USER_SYSTEM_SUSPENDED => :suspended,
    DRMAA::STATE_DONE                  => :completed,
    DRMAA::STATE_FAILED                => :completed
  }

  def translate_drmaa_state(drmaa_state_code)
    DRMMA_TO_OOD_STATE_MAP.fetch(drmaa_state_code, :undetermined)
  end

  def post_process_qstat_job_hash(job_hash)
    # dispatch is not set if the job is not running
    if ! job_hash.key?(:wallclock_time)
      job_hash[:wallclock_time] = job_hash.key?(:dispatch_time) ? Time.now.to_i - job_hash[:dispatch_time] : 0
    end

    job_hash[:status] = translate_sge_state(job_hash[:status])

     job_hash
  end

  # Transform key, value pairs from qstat output to what Info expects
  def post_process_qstat_j_job_hash(job_hash, status)
    # job_hash[:procs] = job_hash[:slots].to_i
    job_hash[:id] = job_hash[:job_number]
    job_hash[:status] = status
    job_hash[:job_name] = job_hash[:job_name]
    job_hash[:accounting_id] = job_hash[:project] if job_hash.key?(:project)
    job_hash[:queue_name] = job_hash[:hard_queue_list]
    job_hash[:job_owner] = job_hash[:owner]
    # job_hash[:wallclock_time] = job_hash[:ru_wallclock].to_i
    job_hash[:submission_time] = Time.parse(job_hash[:submission_time])
    # job_hash[:dispatch_time] = Time.parse(job_hash[:start_time])

    job_hash
  end

  # Get the job status using DRMAA
  def get_status_from_drmma(job_id)
    ENV['SGE_ROOT'] = @sge_root.to_s
    original_ld_library_path = ENV['LD_LIBRARY_PATH']
    ENV['LD_LIBRARY_PATH'] = @ld_library_path.to_s unless @ld_library_path.nil?
    translated_state = translate_drmaa_state(SessionSingleton.instance.job_ps(job_id.to_s))
    ENV['LD_LIBRARY_PATH'] = original_ld_library_path

    translated_state
  end
end