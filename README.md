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
#  :name    => "oak-batch.osc.edu:15001",
#  :attribs => {
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
#  :name    => "oak-batch.osc.edu:15001",
#  :attribs => {
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
#[{
#  :name    => "n0003",
#  :attribs => {
#    :state       => "free",
#    :power_state => "Running",
#    :np          => "12",
#    ...
#  }
#}, {
#  :name    => "n0004",
#  :attribs => {
#    :state       => "free",
#    :power_state => "Running",
#    :np          => "12",
#    ...
#  }
#}, ...]

# To get info about a single node
b.get_node "n0003"
#=> { ... }

# Get list of queues from batch server
# see http://linux.die.net/man/7/pbs_queue_attributes
b.get_queues
#=>
#[{
#  :name    => "batch",
#  :attribs => {
#    :queue_type => "Route",
#    :total_jobs => "2",
#    :enabled    => "True",
#    ...
#  }
#}, {
#  :name    => "serial",
#  :attribs => {
#    :queue_type => "Execution",
#    :total_jobs => "2386",
#    :enabled    => "True",
#    ...
#  }
#}, ...]

# To get info about a single queue
b.get_queue "serial"
#=> { ... }

# Get list of jobs from batch server
# see http://linux.die.net/man/7/pbs_server_attributes
b.get_jobs
#=>
#[{
#  :name    => "6621251.oak-batch.osc.edu",
#  :attribs => {
#    :Job_Name  => "FEA_solver",
#    :Job_Owner => "bob@oakley01.osc.edu",
#    :job_state => "Q",
#    ...
#  }
#}, {
#  :name    => "6621252.oak-batch.osc.edu",
#  :attribs => {
#    :Job_Name  => "CFD_solver",
#    :Job_Owner => "sally@oakley02.osc.edu",
#    :job_state => "R",
#    ...
#  }
#}, ...]

# To get info about a single job
b.get_job "6621251.oak-batch.osc.edu"
#=> { ... }
```
