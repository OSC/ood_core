module PBS
  module Holdable
    # Put job on hold
    def hold(args = {})
      # hold_type::
      # The parameter, hold_type, contains the type of hold to be applied. The possible values are (default is 'u'):
      # "u" : Available to the owner of the job, the batch operator and the batch administrator.
      # "o" : Available to the batch operator and the batch administrator.
      # "s" : Available only to the batch administrator.
      hold_type = args[:hold_type] || "u"

      _pbs_hold(hold_type)
      self
    end

    # Release job from hold
    def release(args = {})
      # hold_type::
      # The parameter, hold_type, contains the type of hold to be applied. The possible values are (default is 'u'):
      # "u" : Available to the owner of the job, the batch operator and the batch administrator.
      # "o" : Available to the batch operator and the batch administrator.
      # "s" : Available only to the batch administrator.
      hold_type = args[:hold_type] || "u"

      _pbs_release(hold_type)
      self
    end

    # Connect to batch server, put job on hold,
    # disconnect, and finally check for errors
    def _pbs_hold(hold_type)
      conn.connect unless conn.connected?
      Torque.pbs_holdjob(conn.conn_id, id, hold_type, nil)
      conn.disconnect
      Torque.check_for_error
    end

    # Connect to batch server, release job from hold,
    # disconnect, and finally check for errors
    def _pbs_release(hold_type)
      conn.connect unless conn.connected?
      Torque.pbs_rlsjob(conn.conn_id, id, hold_type, nil)
      conn.disconnect
      Torque.check_for_error
    end
  end
end
