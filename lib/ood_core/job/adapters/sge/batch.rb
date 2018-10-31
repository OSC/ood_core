# Object used for simplified communication with a SGE batch server
#
# @api private
class OodCore::Job::Adapters::Sge::Batch
  using OodCore::Refinements::HashExtensions
  require "ood_core/job/adapters/sge/qstat_xml_f_r_listener"
  require "ood_core/job/adapters/sge/helper"
  require "ood_core/refinements/hash_extensions"
  require "tempfile"
  require 'time'

  class Error < StandardError; end

  # @param opts [#to_h] the options defining this adapter
  # @option opts [Batch] :batch The Sge batch object
  #
  # @api private
  # @see Factory.build_sge
  def initialize(config)
    @cluster = config.fetch(:cluster, nil)
    @conf    = Pathname.new(config.fetch(:conf, nil))
    @bin     = Pathname.new(config.fetch(:bin, nil))

    @helper = OodCore::Job::Adapters::Sge::Helper.new
  end

  # Get OodCore::Job::Info for every enqueued job, optionally filtering on owner
  # @param owner [#to_s] the owner or owner list
  def get_all(owner: nil)
    listener = QstatXmlFrListener.new
    argv = ['qstat', '-F', '-r', '-xml']
    argv += ['-u', owner] unless owner.nil?
    parser = REXML::Parsers::StreamParser.new(call(*argv), listener)
    parser.parse

    listener.parsed_jobs.map{|job_hash| hash_to_job_info(job_hash)}
  end

  # Get OodCore::Job::Info for a specific job_id
  # It is not ideal to load everything just to get the output of a single job,
  # but SGE's qstat does not give a way to get the status of an enqueued job 
  # with qstat -j $jobid
  def get_info_enqueued_job(job_id)
    job_info = get_all.find{|job_info| job_info.id == job_id}
    job_info = OodCore::Job::Info.new(id: job_id, status: :completed) if job_info.nil?
      
    job_info
  end

  def get_info_historical_job(job_id)
    argv = ['qacct', '-j', job_id]
    
    begin
      result = call(*argv).strip
    rescue
      return nil
    end

    job_hash = @helper.parse_qacct_output(result)

    OodCore::Job::Info.new(**post_process_job_hash(job_hash))
  end

  def hold(job_id)
    call('qhold', job_id)
  end

  def release(job_id)
    call('qrls', job_id)
  end

  def del(job_id)
    call('qdel', job_id)
  end

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

  # http://www.softpanorama.org/HPC/Grid_engine/Queues/queue_states.shtml
  STATE_MAP = {
    'EhRqw' => :undetermined, # allpending states with error
    'Ehqw' => :undetermined, # allpending states with error
    'Eqw' => :undetermined, # allpending states with error
    'RS' => :suspended, # allsuspended withre-submit
    'RT' => :suspended, # allsuspended withre-submit
    'Rr' => :running, # running,re-submit
    'Rs' => :suspended, # allsuspended withre-submit
    'Rt' => :running, # transferring,re-submit
    'RtS' => :suspended, # allsuspended withre-submit
    'RtT' => :suspended, # allsuspended withre-submit
    'Rts' => :suspended, # allsuspended withre-submit
    'S' => :suspended, # queue suspended
    'T' => :suspended, # queue suspended by alarm
    'dRS' => :completed, # all running and suspended states with deletion
    'dRT' => :completed, # all running and suspended states with deletion
    'dRr' => :completed, # all running and suspended states with deletion
    'dRs' => :completed, # all running and suspended states with deletion
    'dRt' => :completed, # all running and suspended states with deletion
    'dS' => :completed, # all running and suspended states with deletion
    'dT' => :completed, # all running and suspended states with deletion
    'dr' => :completed, # all running and suspended states with deletion
    'ds' => :completed, # all running and suspended states with deletion
    'dt' => :completed, # all running and suspended states with deletion
    'hRwq' => :queued_held, # pending,system hold,re-queue
    'hqw' => :queued_held, # pending,system hold
    'qw' => :queued, # pending
    'r' => :running, # running
    's' => :suspended, # suspended
    't' => :running, # transferring
    'tS' => :suspended, # queue suspended
    'tT' => :suspended, # queue suspended by alarm
    'ts' => :suspended, # obsuspended
  }

  def translate_state(sge_state_code)
    STATE_MAP.fetch(sge_state_code, :undetermined)
  end

  def hash_to_job_info(job_hash)
    # dispatch is not set if the job is not running
    if ! job_hash.key?(:wallclock_time)
      job_hash[:wallclock_time] = job_hash.key?(:dispatch_time) ? Time.now.to_i - job_hash[:dispatch_time] : 0  
    end
    
    job_hash[:status] = translate_state(job_hash[:status])

     OodCore::Job::Info.new(**job_hash)
  end

  def post_process_job_hash(job_hash)
    job_hash[:procs] = job_hash[:slots].to_i
    job_hash[:id] = job_hash[:jobnumber]
    job_hash[:status] = :completed
    job_hash[:job_name] = job_hash[:jobname]
    job_hash[:account] = job_hash[:project]
    job_hash[:queue_name] = job_hash[:qname]
    job_hash[:user] = job_hash[:owner]
    job_hash[:wallclock_time] = job_hash[:ru_wallclock].to_i
    job_hash[:submission_time] = Time.parse(job_hash[:qsub_time])
    job_hash[:dispatch_time] = Time.parse(job_hash[:start_time])

    job_hash
  end
end