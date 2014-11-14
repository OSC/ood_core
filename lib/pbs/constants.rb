#
# Copyright (C) 2014 Jeremy Nicklas
#
# This file is part of ruby-ffi.
#
# All rights reserved.
#

module PBS

  # Attribute Names used by user commands
  ATTR_a = "Execution_Time"
  ATTR_c = "Checkpoint"
  ATTR_e = "Error_Path"
  ATTR_f = "fault_tolerant"
  ATTR_g = "group_list"
  ATTR_h = "Hold_Types"
  ATTR_j = "Join_Path"
  ATTR_k = "Keep_Files"
  ATTR_l = "Resource_List"
  ATTR_m = "Mail_Points"
  ATTR_o = "Output_Path"
  ATTR_p = "Priority"
  ATTR_q = "destination"
  ATTR_r = "Rerunable"
  ATTR_t = "job_array_request"
  ATTR_array_id = "job_array_id"
  ATTR_u = "User_List"
  ATTR_v = "Variable_List"
  ATTR_A = "Account_Name"
  ATTR_args = "job_arguments"           # Oakley only
  ATTR_M = "Mail_Users"
  ATTR_N = "Job_Name"
  ATTR_S = "Shell_Path_List"
  ATTR_depend = "depend"
  ATTR_inter = "interactive"
  ATTR_stagein = "stagein"
  ATTR_stageout = "stageout"
  ATTR_jobtype = "jobtype"
  ATTR_submit_host = "submit_host"      # Oakley only
  ATTR_init_work_dir = "init_work_dir"  # Oakley only

end
