require 'rexml/document'
require 'rexml/streamlistener'
require 'date'
require 'ood_core'
require 'ood_core/job/array_ids'

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
# :wallclock_time

class QstatXmlJRListener
  # [Hash]
  attr_reader :parsed_job

  include REXML::StreamListener

  def initialize
    @parsed_job = {
      :tasks => [],
      :status => :queued,
      :procs => 1,
      :native => {
        :ST_name => ''
      } 
    }
    @current_text = nil
    @current_request = nil
    @processing_JB_stdout_path_list = false

    @processing_job_array_spec = false
    @adding_slots = false

    @job_array_spec = {
      start: nil,
      stop: nil,
      step: 1,  # Step can have a default of 1
    }
    @running_tasks = []
    @native_tags = ['JB_job_number', 'JB_job_name', 'JB_version', 'JB_project', 'JB_exec_file', 'JB_script_file', 'JB_script_size', 'JB_submission_time', 'JB_execution_time', 'JB_deadline', 'JB_owner', 'JB_uid', 'JB_group', 'JB_gid', 'JB_account', 'JB_cwd', 'JB_notify', 'JB_type', 'JB_reserve', 'JB_priority', 'JB_jobshare', 'JB_verify', 'JB_checkpoint_attr', 'JB_checkpoint_interval', 'JB_restart']
  end

  def tag_start(name, attrs)
    case name
    when 'task_id_range'
      toggle_processing_array_spec
    when 'JB_pe_range'
      toggle_adding_slots
    when 'JB_stdout_path_list'
      @processing_JB_stdout_path_list = true
    end
  end

  def tag_end(name)
    #Add to native hash if in native_tags
    if (@native_tags.include?(name))
      @parsed_job[:native][:"#{name}"] = @current_text
    end

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
    when 'JAT_task_number'
      end_JAT_task_number
    when 'djob_info'
      finalize_parsed_job
    when 'RN_min'
      set_job_array_piece(:start) if @processing_job_array_spec
      set_slots if @adding_slots
    when 'RN_max'
      set_job_array_piece(:stop) if @processing_job_array_spec
    when 'RN_step'
      set_job_array_piece(:step) if @processing_job_array_spec
    when 'task_id_range'
      toggle_processing_array_spec
    when 'JB_pe_range'
      toggle_adding_slots
    when 'PN_path' 
      end_PN_path
    when 'ST_name'
      end_ST_name
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
    @parsed_job[:submission_time] = ms_to_seconds(@current_text.to_i)
  end

  def end_JB_ja_tasks
    @parsed_job[:status] = :running
  end

  def end_JAT_start_time
    @parsed_job[:status] = :running
    @parsed_job[:dispatch_time] = ms_to_seconds(@current_text.to_i)
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

  # Used to record a running Job Array task
  def end_JAT_task_number
    @running_tasks << @current_text
  end

  def end_PN_path
    @parsed_job[:native][:PN_path] = @current_text if @processing_JB_stdout_path_list
    @processing_JB_stdout_path_list = false
  end

  def end_ST_name
    @parsed_job[:native][:ST_name] = @parsed_job[:native][:ST_name] + @current_text + ' '
  end

  def set_job_array_piece(key)
    @job_array_spec[key] = @current_text if @processing_job_array_spec
  end

  def spec_string
    # If any of the job_array_spec values are nil then return a default spec_string
    if @job_array_spec.values.any? { |value| value.nil? } 
      '1-1:1'
    else
      '%{start}-%{stop}:%{step}' % @job_array_spec
    end
  end

  def build_tasks
    all_task_ids = OodCore::Job::ArrayIds.new(spec_string).ids
    highest_id_running = @running_tasks.sort.last.to_i
    
    @running_tasks.sort.map{
      |task_id| { :id => task_id, :status => :running }
    } + all_task_ids.select{
      |task_id| task_id > highest_id_running
    }.map{
      |task_id| { :id => task_id, :status => :queued }
    }
  end

  # Used to finalize the parsed job
  def finalize_parsed_job
    @parsed_job[:tasks] = build_tasks if need_to_build_job_array?
  end

  # The XML output will always contain nodes for task_id_range, even when the
  # job is not an array job.
  def need_to_build_job_array?
    spec_string != '1-1:1'
  end

  def toggle_processing_array_spec
    @processing_job_array_spec = ! @processing_job_array_spec
  end

  def toggle_adding_slots
    @adding_slots = ! @adding_slots
  end

  def set_slots
    @parsed_job[:procs] = @current_text.to_i
  end

  private

  # Some Grid Engines (like UGE) use milliseconds were others use
  # seconds past the epoch.
  def ms_to_seconds(raw)
    raw.digits.length >= 13 ? raw / 1000 : raw
  end
end
