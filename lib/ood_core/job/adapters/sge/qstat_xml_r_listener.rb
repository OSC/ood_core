require 'rexml/document'
require 'rexml/streamlistener'
require 'date'

# An XML stream listener to build an array of OodCore::Job::Info from qstat output
#
# Handles parsing `qstat -xml -r` which provides:
# :accounting_id
# :id
# :job_name
# :job_owner
# :procs
# :queue_name
# :status
# :wallclock_limit

class QstatXmlRListener
  # [Array<Hash>]
  attr_reader :parsed_jobs

  include REXML::StreamListener

  def initialize
    @parsed_jobs = []
    @current_job = {
      :tasks => [],
      :native => {}  # TODO: improve native reporting
    }
    @current_text = nil

    @current_request = nil
  end

  def tag_start(name, attributes)
    case name
    when 'hard_request'
      start_hard_request(attributes)
    end
  end

  def tag_end(name)
    case name
    when 'job_list'
      end_job_list
    when 'JB_job_number'
      end_JB_job_number
    when 'JB_name'
      end_JB_name
    when 'JB_owner'
      end_JB_owner
    when 'JB_project'
      end_JB_project
    when 'state'
      end_state
    when 'slots'
      end_slots
    when 'JB_submission_time'
      end_JB_submission_time
    when 'hard_req_queue'
      end_hard_req_queue
    when 'JAT_start_time'
      end_JAT_start_time
    when 'hard_request'
      end_hard_request
    when 'tasks'
      add_child_tasks
    end
  end

  # Always store text nodes temporarily
  def text(text)
    @current_text = text
  end

  # Handle hard_request tags
  #
  # Multiple hard_request tags may be present and will be differentiated using their name attribute
  def start_hard_request(attributes)
    if attributes.key?('name')
      @current_request = attributes['name']
    else
      @current_request = nil
    end
  end

  # Attributes we need
  def end_JB_job_number
    @current_job[:id] = @current_text
  end

  def end_JB_owner
    @current_job[:job_owner] = @current_text
  end

  def end_JB_project
    @current_job[:accounting_id] = @current_text
  end

  def end_JB_name
    @current_job[:job_name] = @current_text
  end

  # Note that this is the native SGE type
  def end_state
    @current_job[:status] = @current_text
  end

  def end_slots
    @current_job[:procs] = @current_text.to_i
  end

  def end_hard_req_queue
    @current_job[:queue_name] = @current_text
  end

  def end_JB_submission_time
    @current_job[:submission_time] = DateTime.parse(@current_text).to_time.to_i
  end

  def end_JAT_start_time
    @current_job[:dispatch_time] = DateTime.parse(@current_text).to_time.to_i
  end

  def end_hard_request
    return nil if @current_request.nil?

    case @current_request
    when 'h_rt'  # hard run time limit
      @current_job[:wallclock_limit] = @current_text.to_i
    end
  end

  # Store a completed job and reset current_job for the next pass
  def end_job_list
    @parsed_jobs << @current_job
    @current_job = {
      :tasks => [],
      :native => {}
    }
  end

  def add_child_tasks
    @current_job[:tasks] = OodCore::Job::ArrayIds.new(@current_text).ids.sort.map{
      |task_id| { :id => task_id, :status => :queued }
    }
  end
end

