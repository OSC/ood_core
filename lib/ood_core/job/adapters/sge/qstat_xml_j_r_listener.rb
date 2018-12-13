require 'rexml/document'
require 'rexml/streamlistener'
require 'date'

# An XML stream listener to build an array of OodCore::Job::Info from qstat output
#
# Handles parsing `qstat -xml -r -j` which provides:
# :accounting_id
# :id
# :job_name
# :job_owner
# :procs
# :queue_name
# :status
# :wallclock_limit


# :wallclock_time  # HOW LONG HAS IT BEEN RUNNING?

class QstatXmlJRListener
  # [Hash]
  attr_reader :parsed_job

  include REXML::StreamListener

  def initialize
    @parsed_job = {
      :status => :queued,
      :procs => 1,  # un-knowable from SGE qstat output
    }
    @current_text = nil
    @current_request = nil
  end

  def tag_end(name)
    case name
    when 'JB_ja_tasks'
      end_JB_ja_tasks
    when 'JB_job_number'
      end_JB_job_number
    when 'JB_job_name'
      end_JB_job_name
    when 'JB_owner'
      end_JB_owner
    when 'JB_project'
      end_JB_project
    when 'JB_submission_time'
      end_JB_submission_time
    when 'hard_request'
      end_hard_request
    when 'JAT_start_time'
      end_JAT_start_time
    when 'CE_name'
      end_CE_name
    when 'CE_stringval'
      end_CE_stringval
    when 'QR_name'
      end_QR_name
    end
  end

  # Always store text nodes temporarily
  def text(text)
    @current_text = text
  end

  # Attributes we need
  def end_JB_job_number
    @parsed_job[:id] = @current_text
  end

  def end_JB_owner
    @parsed_job[:job_owner] = @current_text
  end

  def end_JB_project
    @parsed_job[:accounting_id] = @current_text
  end

  def end_JB_job_name
    @parsed_job[:job_name] = @current_text
  end

  def end_JB_submission_time
    @parsed_job[:submission_time] = @current_text.to_i
  end

  def end_JB_ja_tasks
    @parsed_job[:status] = :running
  end

  def end_JAT_start_time
    @parsed_job[:status] = :running
    @parsed_job[:dispatch_time] = @current_text.to_i
    @parsed_job[:wallclock_time] = Time.now.to_i - @parsed_job[:dispatch_time]
  end

  def end_CE_name
    @current_request = @current_text
  end

  def end_CE_stringval
    return nil if @current_request.nil?

    case @current_request
    when 'h_rt'  # hard run time limit
      @parsed_job[:wallclock_limit] = @current_text.to_i
    end
  end

  def end_QR_name
    @parsed_job[:queue_name] = @current_text
  end
end

