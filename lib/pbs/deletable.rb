module PBS
  module Deletable
    # Delete job
    def delete(args = {})
      _pbs_delete()
    end

    # Connect to batch server, delete job,
    # disconnect, and finally check for errors
    def _pbs_delete()
      conn.connect unless conn.connected?
      Torque.pbs_deljob(conn.conn_id, id, nil)
      conn.disconnect
      Torque.check_for_error
    end
  end
end
