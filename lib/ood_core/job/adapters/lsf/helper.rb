# Object used for simplified communication with a LSF batch server
#
# @api private
class OodCore::Job::Adapters::Lsf::Helper

  # convert string in format "03/31-14:46:42" to Time object
  # assumes time being parsed is a time that ocurred in the past
  # not to be used for parsing times in the future (like estimated FINISH_TIME)
  def parse_past_time(t, ignore_errors: false)
    return nil if t.nil? || t.empty? || t == "-"
    year = Time.now.year
    time = Time.parse("#{year}/#{t}")

    # handle edge case where job started before new year
    time = Time.parse("#{year - 1}/#{t}") if time.month > Time.now.month

    time

  rescue ArgumentError => e
    raise e unless ignore_errors

    #TODO: warn via logger

    nil
  end
end
