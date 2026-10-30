require 'test_helper'
require 'ood_core/job/adapters/flux'
require 'ood_core/job/adapters/htcondor'
require 'ood_core/job/adapters/lsf'
require 'ood_core/job/adapters/pbspro'
require 'ood_core/job/adapters/psij'
require 'ood_core/job/adapters/sge'
require 'ood_core/job/adapters/slurm'
require 'ood_core/job/adapters/torque'

# With a submit_host, every adapter runs its commands through ssh.
# bin_overrides['ssh'] should replace that ssh, and without it, plain 'ssh'
# should be used, even when the adapter has a bin directory set.
class TestSshBinOverride < Minitest::Test
  include TestHelper

  BIN = '/opt/scheduler/bin'.freeze
  SSH = '/opt/ssh/bin/ssh'.freeze

  # adapter => [its Batch class, a command to run, the options to build the Batch with]
  ADAPTERS = {
    'flux'     => [OodCore::Job::Adapters::Flux::Batch,     'jobs',     { bin: BIN }],
    'htcondor' => [OodCore::Job::Adapters::HTCondor::Batch, 'condor_q', { bin: BIN }],
    'lsf'      => [OodCore::Job::Adapters::Lsf::Batch,      'bjobs',    { bindir: BIN }],
    'pbspro'   => [OodCore::Job::Adapters::PBSPro::Batch,   'qstat',    { pbs_exec: BIN }],
    'psij'     => [OodCore::Job::Adapters::PSIJ::Batch,     'psij_cmd', { bin: BIN }],
    'sge'      => [OodCore::Job::Adapters::Sge::Batch,      'qstat',    { bin: BIN }],
    'slurm'    => [OodCore::Job::Adapters::Slurm::Batch,    'squeue',   { bin: BIN }],
    'torque'   => [OodCore::Job::Adapters::Torque::Batch,   'qstat',    { bin: BIN, host: 'batch.osc.edu' }]
  }.freeze

  def setup
    # building an HTCondor Batch otherwise runs condor_version
    OodCore::Job::Adapters::HTCondor::Batch.any_instance.stubs(:get_htcondor_version).returns(Gem::Version.new('24.0.0'))
  end

  def expect_ssh(ssh)
    Open3.expects(:capture3).with { |_env, cmd, *_args| cmd == ssh }.returns(['', '', exit_success])
  end

  ADAPTERS.each do |adapter, (batch_class, command, options)|
    define_method("test_#{adapter}_uses_ssh_from_bin_overrides") do
      batch = batch_class.new(**options, submit_host: 'owens.osc.edu', bin_overrides: { 'ssh' => SSH })

      expect_ssh(SSH)
      batch.send(:call, command)
    end

    define_method("test_#{adapter}_does_not_look_for_ssh_in_bin") do
      batch = batch_class.new(**options, submit_host: 'owens.osc.edu', bin_overrides: {})

      expect_ssh('ssh')
      batch.send(:call, command)
    end
  end
end
