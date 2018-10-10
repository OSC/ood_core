# Object used for simplified communication with a SGE batch server
#
# @api private
class OodCore::Job::Adapters::Sge::Batch
  require "ood_core/job/adapters/sge/qstat_xml_f_r_listener"
  require 'rexml/document'
  require 'time'

  def initialize(config)
    @cluster = config.fetch(:cluster, nil)
    @conf    = Pathname.new(config.fetch(:conf, nil))
    @bin     = Pathname.new(config.fetch(:bin, nil))
  end

  def get_all
    listener = QstatXmlFrListener.new
    parser = REXML::Parsers::StreamParser.new(call('qstat', '-F', '-r', '-xml'), listener)
    parser.parse

    listener.parsed_jobs.map{|job_hash| hash_to_job_info(job_hash)}
  end

  private

    # Call a forked SGE command for a given batch server
    def call(cmd, *args, env: {}, stdin: "", chdir: nil)
      cmd = cmd.to_s
      cmd = @bin.join(cmd).to_s if @bin
      args = args.map(&:to_s)
      env = env.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
      # env["PBS_DEFAULT"] = host.to_s if host
      # env["PBS_EXEC"]    = bin.to_s if bin
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
      'dRS' => :complete, # all running and suspended states with deletion
      'dRT' => :complete, # all running and suspended states with deletion
      'dRr' => :complete, # all running and suspended states with deletion
      'dRs' => :complete, # all running and suspended states with deletion
      'dRt' => :complete, # all running and suspended states with deletion
      'dS' => :complete, # all running and suspended states with deletion
      'dT' => :complete, # all running and suspended states with deletion
      'dr' => :complete, # all running and suspended states with deletion
      'ds' => :complete, # all running and suspended states with deletion
      'dt' => :complete, # all running and suspended states with deletion
      'hRwq' => :queued, # pending,system hold,re-queue
      'hqw' => :queued, # pending,system hold
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
      job_hash[:wallclock_time] = job_hash.key?(:dispatch_time) ? Time.now.to_i - job_hash[:dispatch_time] : 0
      job_hash[:status] = translate_state(job_hash[:status])

       OodCore::Job::Info.new(**job_hash)
    end
end