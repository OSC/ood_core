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

# Delete submitted job
PBS.pbs_deljob(c, pbsid, '')
puts "Deleted job: #{pbsid}"

# Disconnect
PBS.pbs_disconnect(c)
