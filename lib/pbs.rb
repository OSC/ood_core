module PBS
  # Config path
  CONFIG_PATH = File.dirname(__FILE__) + "/../config"
end

require "pbs/error"
require "pbs/attributes"
require "pbs/torque"
require "pbs/conn"
require "pbs/query"
require "pbs/submittable"
require "pbs/statusable"
require "pbs/holdable"
require "pbs/deletable"
require "pbs/job"
require "pbs/version"
