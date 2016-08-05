# PBS Ruby

## Description

Ruby wrapper for the Torque C Library utilizing Ruby-FFI. This has been
successfully tested with Torque 4.2.10 and greater. Your mileage may vary.

## Installation

Add this to your application's Gemfile:

```ruby
gem 'pbs'
```

And then execute:

```bash
$ bundle install
```

## Usage

All communication with a specific batch server is handled through the `Batch`
object. You can generate this object for a given batch server and Torque client
installation as:

```ruby
# Create new batch object for OSC's Oakley batch server
oakley = PBS::Batch.new(host: 'oak-batch.osc.edu', prefix: '/usr/local/torque/default')

# Get status information for this batch server
# see http://linux.die.net/man/7/pbs_server_attributes
oakley.get_status
#=>
#{
#  "oak-batch.osc.edu:15001" => {
#    :server_state  => "Idle",
#    :total_jobs    => "2514",
#    :default_queue => "batch",
#    ...
#  }
#}

# Get status information but only filter through specific attributes
oakley.get_status(filters: [:server_state, :total_jobs])
#=>
#{
#  "oak-batch.osc.edu:15001" => {
#    :server_state  => "Idle",
#    :total_jobs    => "2514"
#  }
#}
```

You can also query information about the nodes, queues, and jobs running on
this batch server:

```ruby
# Get list of nodes from batch server
b.get_nodes
#=>
#{
#  "n0003" => {
#    :state       => "free",
#    :power_state => "Running",
#    :np          => "12",
#    ...
#  },
#  "n0004" => {
#    :state       => "free",
#    :power_state => "Running",
#    :np          => "12",
#    ...
#  }, ...
#}

# To get info about a single node
b.get_node("n0003")
#=> { ... }

# Get list of queues from batch server
# see http://linux.die.net/man/7/pbs_queue_attributes
b.get_queues
#=>
#{
#  "batch" => {
#    :queue_type => "Route",
#    :total_jobs => "2",
#    :enabled    => "True",
#    ...
#  },
#  "serial" => {
#    :queue_type => "Execution",
#    :total_jobs => "2386",
#    :enabled    => "True",
#    ...
#  }, ...
#}

# To get info about a single queue
b.get_queue("serial")
#=> { ... }

# Get list of jobs from batch server
# see http://linux.die.net/man/7/pbs_server_attributes
b.get_jobs
#=>
#{
#  "6621251.oak-batch.osc.edu" => {
#    :Job_Name  => "FEA_solver",
#    :Job_Owner => "bob@oakley01.osc.edu",
#    :job_state => "Q",
#    ...
#  },
#  "6621252.oak-batch.osc.edu" => {
#    :Job_Name  => "CFD_solver",
#    :Job_Owner => "sally@oakley02.osc.edu",
#    :job_state => "R",
#    ...
#  }, ...
#}

# To get info about a single job
b.get_job("6621251.oak-batch.osc.edu")
#=> { ... }
```

### Simple Job Submission

To submit a script to the batch server:

```ruby
# Simple job submission
job_id = b.submit_script("/path/to/script")
#=> "7166037.oak-batch.osc.edu"

# Get job information for this job
b.get_job(job_id)
#=> { ... }

# Hold this job
b.hold_job(job_id)

# Release this job
b.release_job(job_id)

# Delete this job
b.delete_job(job_id)
```

To submit a string to the batch server:

```ruby
# Submit a string to the batch server
job_id = b.submit_string("sleep 60")
```

The above command will actually generate a temporary file on the local disk and
submit that to the batch server before it is cleaned up.

### Advanced Job Submission

You can programmatically define the PBS directives of your choosing. They will
override any set within the batch script.

Define headers:

```ruby
# Define headers:
#   -N job_name
#   -j oe
#   -o /path/to/output
headers = {
  PBS::ATTR[:N] => "job_name",
  PBS::ATTR[:j] => "oe",
  PBS::ATTR[:o] => "/path/to/output"
}

# or you can directly call the key
headers = {
  Job_Name: "job_name",
  Join_Path: "oe",
  Output_Path: "/path/to/output"
}
```

Define resources (directives that begin with `-l`):

```ruby
# Define resources:
#   -l nodes=1:ppn=12
#   -l walltime=05:00:00
resources = {
  nodes: "1:ppn=12",
  walltime: "05:00:00"
}
```

Define environment variables (directive that begins with `-v`):

```ruby
# Define environment variables that will be exposed to batch job
envvars = {
  TOKEN: 'a8dsjf873js0k',
  USE_GUI: 1
}
```

Submit job with these directives:

```ruby
# Advanced job submission
job_id = b.submit_script("/path/to/script", headers: headers, resources: resources, envvars: envvars)

# Get job info
b.get_job(job_id)
```
