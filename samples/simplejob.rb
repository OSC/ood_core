require 'pbs'

require 'tempfile'
require 'socket'

# Connect to local server
server = PBS.pbs_default()
c = PBS.pbs_connect(server)

# Setup new job
host = Socket.gethostname
attropl = []
attropl << {name: PBS::ATTR_N, value: "testing123"}
attropl << {name: PBS::ATTR_l, resource: "walltime", value: "00:10:00"}
attropl << {name: PBS::ATTR_o, value: "#{host}:#{Dir.pwd}/"}
attropl << {name: PBS::ATTR_e, value: "#{host}:#{Dir.pwd}/"}
attropl << {name: PBS::ATTR_j, value: "oe"}

# Submit new job
pbsid = nil
Tempfile.create('foo', Dir.pwd) do |f|
  f.write("echo \"Hello world!\"")
  f.close()
  pbsid = PBS.pbs_submit(c, attropl, f.path, nil, nil)
  puts "Submitted job: #{pbsid}"
end

# Show details of submitted job
jobs = PBS.pbs_statjob(c, pbsid, nil, nil)
jobs.each do |job|
  job[:attribs].each do |attrib|
    line = "#{job[:name]} --- #{attrib[:name]} "
    line << "(#{attrib[:resource]}) " if attrib[:resource]
    line << "= #{attrib[:value]}"
    puts line
  end
end

# Hold job
PBS.pbs_holdjob(c, pbsid, 'u', nil)
puts "Holding job: #{pbsid}"

# Show status of job
jobs = PBS.pbs_statjob(c, pbsid, nil, nil)
puts "Status of job: #{jobs[0][:attribs].detect { |f| f[:name] == "job_state" }[:value]}"

# Release job
PBS.pbs_rlsjob(c, pbsid, 'u', nil)
puts "Releasing job: #{pbsid}"

# Show status of job
jobs = PBS.pbs_statjob(c, pbsid, nil, nil)
puts "Status of job: #{jobs[0][:attribs].detect { |f| f[:name] == "job_state" }[:value]}"

# Delete submitted job
PBS.pbs_deljob(c, pbsid, '')
puts "Deleted job: #{pbsid}"

# Disconnect
PBS.pbs_disconnect(c)
