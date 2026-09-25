require 'test_helper'
require 'ood_core/job/adapters/slurm'

class TestSlurm < Minitest::Test
  include TestHelper

  TIME_FORMAT_ENV = { 'SLURM_TIME_FORMAT' => '%Y-%m-%dT%H:%M:%S%z' }.freeze

  def slurm_instance(config = {})
    OodCore::Job::Factory.build({ adapter: 'slurm', id: 'owens' }.merge(config))
  end

  def slurm_instance_fixture(cluster = 'glen')
    dir = "spec/fixtures/config/clusters.d"
    clusters = OodCore::Clusters.load_file(dir)

    clusters[cluster.to_sym].job_adapter
  end

  def test_submit_interface
    slurm = slurm_instance

    assert(slurm.respond_to?(:submit))
    veryify_keywords(slurm, :submit, [:after, :afterok, :afternotok, :afterany])
    verify_args(slurm, :submit, 1)
  end

  def test_submitting_with_hold
    slurm = slurm_instance
    stub_submit
    OodCore::Job::Adapters::Slurm::Batch.any_instance.expects(:submit_string).with(script_content, args: ["-H", "--export", "NONE"], env: {})
    slurm.submit(build_script(submit_as_hold: true))
  end

  def test_passing_id
    adapter = slurm_instance_fixture

    slurm = adapter.instance_variable_get(:@slurm)
    assert_equal(slurm.id, 'glen')
  end

  def test_account_info
    adapter = slurm_instance
    stub_etc
    Open3.stubs(:capture3).with(
      TIME_FORMAT_ENV, 'sacctmgr', '-nP', 'show', 'users', 'withassoc', 'format=account,qos', 'where', 'user=me', 'cluster=owens', stdin_data: ''
    ).returns([File.read('spec/fixtures/output/slurm/sacctmgr_show_accts_owens.txt'), '', exit_success])

    accounts = adapter.accounts
    assert_equal(accounts.map(&:name), ["pzs1124", "pzs1118", "pzs1117", "pzs1010", "pzs0715", "pzs0714", "pde0006", "pas2051", "pas1871", "pas1754", "pas1604"])
    accounts.each { |account| assert_equal(account.cluster, 'owens') }
  end

  def test_cluster_info
    adapter = slurm_instance
    Open3.stubs(:capture3).with(TIME_FORMAT_ENV, 'sinfo', '-aho %F/%C', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/sinfo_fc.txt'), '', exit_success])
    Open3.stubs(:capture3).with(TIME_FORMAT_ENV, 'sinfo', '-ahNO', 'nodehost:100,gres:512,gresused:512,statelong', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/sinfo_gres.txt'), '', exit_success])

    info = adapter.cluster_info
    assert_equal(info.active_nodes, 281)
    assert_equal(info.total_nodes, 298)
    assert_equal(info.active_processors, 25_608)
    assert_equal(info.total_processors, 37_376)
    assert_equal(info.active_gpus, 621)
    assert_equal(info.total_gpus, 656)
  end

  # Regression test: sinfo -O nodehost defaults to a 20-char column. When the
  # actual hostname is longer than 20 chars, sinfo truncates without inserting
  # a separating space and the gres/gresused columns get shifted, causing
  # total_gpus to be parsed from GresUsed and active_gpus to evaluate to 0.
  def test_cluster_info_long_hostnames
    adapter = slurm_instance
    Open3.stubs(:capture3).with(TIME_FORMAT_ENV, 'sinfo', '-aho %F/%C', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/sinfo_fc_long_hostnames.txt'), '', exit_success])
    Open3.stubs(:capture3).with(TIME_FORMAT_ENV, 'sinfo', '-ahNO', 'nodehost:100,gres:512,gresused:512,statelong', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/sinfo_gres_long_hostnames.txt'), '', exit_success])

    info = adapter.cluster_info
    assert_equal(info.active_nodes, 3)
    assert_equal(info.total_nodes, 3)
    assert_equal(info.active_processors, 24)
    assert_equal(info.total_processors, 24)
    # 8 + 4 from the two non-drained nodes; the drained node is filtered out.
    assert_equal(info.active_gpus, 12)
    # 8 + 8 from the two non-drained nodes.
    assert_equal(info.total_gpus, 16)
  end

  def test_null_submission_time
    adapter = slurm_instance
    Open3.stubs(:capture3).with(
      TIME_FORMAT_ENV, 'squeue', '--all', '--states=all', '--noconvert', '-O', "Account:\u001F,JobID:\u001F,BatchHost:\u001F,MinCpus:\u001F,NumCPUs:\u001F,MinTmpDisk:\u001F,NumNodes:\u001F,EndTime:\u001F,Dependency:\u001F,Feature:\u001F,ArrayJobID:\u001F,GroupName:\u001F,GroupID:\u001F,OverSubscribe:\u001F,Sockets:\u001F,JobArrayID:\u001F,Cores:\u001F,Name:\u001F,Threads:\u001F,Comment:\u001F,ArrayTaskID:\u001F,TimeLimit:\u001F,TimeLeft:\u001F,MinMemory:\u001F,TimeUsed:\u001F,ReqNodes:\u001F,NodeList:\u001F,Command:\u001F,Contiguous:\u001F,QOS:\u001F,Partition:\u001F,PriorityLong:\u001F,Reason:\u001F,StartTime:\u001F,StateCompact:\u001F,State:\u001F,UserName:\u001F,UserID:\u001F,Reservation:\u001F,SubmitTime:\u001F,WCKey:\u001F,Licenses:\u001F,ExcNodes:\u001F,CoreSpec:\u001F,Nice:\u001F,SchedNodes:\u001F,SCT:\u001F,WorkDir:\u001F,tres-alloc:\u001F,tres-per-node:\u001F,", stdin_data: ''
    ).returns([File.read('spec/fixtures/output/slurm/null_submit_time.txt'), '', exit_success])

    jobs = adapter.info_all
    bad_job = jobs.find { |job| job.id == '6779842' }

    assert_nil(bad_job.submission_time)
    assert_equal(4, jobs.size)
  end

  def test_nil_parse_time
    adapter = slurm_instance
    assert_nil(adapter.send(:parse_time, nil))
  end

  def test_queues_with_tres_null
    adapter = slurm_instance
    Open3.stubs(:capture3).with(TIME_FORMAT_ENV, 'scontrol', 'show', 'part', '-o', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/owens_partitions.txt'), '', exit_success])

    queues = adapter.queues
    queue = queues.find { |q| q.name == 'dynamic' }

    refute_nil(queue)
    assert_equal({}, queue.tres)
  end

  def test_info_historic_uses_alloc_tres
    batch = OodCore::Job::Adapters::Slurm::Batch.new(
      conf: '/etc/slurm/conf/',
      bin: nil,
      bin_overrides: { 'sacct' => 'spec/fixtures/scripts/sacct.rb' }
    )
    jobs = OodCore::Job::Adapters::Slurm.new(slurm: batch).info_historic
    job = jobs.find { |j| j.id == '20251' }

    # ReqTRES says mem=0.98G but AllocTRES says mem=1.96G
    assert_equal(2_104_533_975, job.total_memory)
    assert_equal(1, job.gpus)
  end

  def test_gpus_from_tres_sums_multiple_types_without_rollup
    tres = 'cpu=8,gres/gpu:a100=2,gres/gpu:v100=1,node=1'

    assert_equal(3, OodCore::Job::Adapters::Slurm.gpus_from_tres(tres))
  end

  def test_queue_info
    adapter = slurm_instance
    Open3.stubs(:capture3).with(TIME_FORMAT_ENV, 'scontrol', 'show', 'part', '-o', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/owens_partitions.txt'), '', exit_success])

    queues = adapter.queues
    batch = queues.find { |q| q.name == 'batch' }
    hugemem = queues.find { |q| q.name == 'hugemem' }
    parallel = queues.find { |q| q.name == 'parallel' }

    assert_nil(batch.max_cpus)
    assert_equal(48, hugemem.max_cpus)
    assert_equal(28, parallel.max_cpus)

    assert_nil(batch.max_nodes)
    assert_equal(1, hugemem.max_nodes)
    assert_equal(81, parallel.max_nodes)

    assert_equal(0, batch.min_nodes)
    assert_equal(0, hugemem.min_nodes)
    assert_equal(2, parallel.min_nodes)

    assert_equal(604_800, batch.max_time)
    assert_equal(604_800, hugemem.max_time)
    assert_equal(345_600, parallel.max_time)
  end

  def test_memory_from_tres_handles_decimal_values
    assert_equal(4_219_805_368,
      OodCore::Job::Adapters::Slurm.memory_from_tres('billing=1,cpu=1,mem=3.93G,node=1'))
  end

  def test_memory_from_tres_handles_integer_values
    assert_equal(68_719_476_736,
      OodCore::Job::Adapters::Slurm.memory_from_tres('cpu=17,mem=64G,node=1'))
  end

  def test_memory_from_tres_without_a_unit_is_bytes
    assert_equal(512, OodCore::Job::Adapters::Slurm.memory_from_tres('cpu=8,mem=512,node=1'))
  end

  def test_memory_from_tres_returns_nil_without_memory
    assert_nil(OodCore::Job::Adapters::Slurm.memory_from_tres('billing=1,cpu=1,node=1'))
  end

  def test_relative_time
    now = Time.utc(2026, 2, 11, 12, 0, 0)

    assert_equal('now', OodCore::Job::Adapters::Slurm.relative_time(now, now: now))
    assert_equal('now+3600', OodCore::Job::Adapters::Slurm.relative_time(now + 3600, now: now))
    assert_equal('now-86400', OodCore::Job::Adapters::Slurm.relative_time(now - 86400, now: now))
    assert_equal('now', OodCore::Job::Adapters::Slurm.relative_time(DateTime.new(2026, 2, 11, 13, 0, 0, '+01:00'), now: now))
  end

  def test_sacct_timestamps_are_parsed_with_utc_offset
    sacct_line = [
      "ood", "ood", "5963565", "RStudio", "00:00:03", "0.98G", "2", "1", "01:00:00", "CANCELLED by 1001", "00:00:00", "",
      "interactive", "2026-02-11T15:12:58+0200", "2026-02-11T15:13:00+0200", "2026-02-11T15:13:03+0200", "billing=1,cpu=1,mem=0.98G,node=1",
      "billing=1,cpu=1,mem=0.98G,node=1"
    ].join("\u001F")
    Open3.expects(:capture3).with { |env, cmd, *| env == TIME_FORMAT_ENV && cmd == 'sacct' }.returns([sacct_line, '', exit_success])

    job = slurm_instance.info_historic.first
    assert_equal(Time.utc(2026, 2, 11, 13, 12, 58), job.submission_time)
    assert_equal(Time.utc(2026, 2, 11, 13, 13, 0), job.dispatch_time)
  end

  def test_time_format_is_set_for_commands_other_than_job_submission
    adapter = slurm_instance
    ['squeue', 'scancel', 'scontrol'].each do |command|
      Open3.expects(:capture3).with { |env, cmd, *| env == TIME_FORMAT_ENV && cmd == command }.returns(['', '', exit_success])
    end

    adapter.info('123')
    adapter.delete('123')
    adapter.queues
  end

  def test_time_format_is_exported_on_the_submit_host
    ssh_args = ['ssh', '-p', '22', '-o', 'BatchMode=yes', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=yes',
                'owens.osc.edu', 'export SLURM_TIME_FORMAT=%Y-%m-%dT%H:%M:%S%z;', 'sacct']
    Open3.expects(:capture3).with { |_env, *args| args.first(ssh_args.size) == ssh_args }.returns(['', '', exit_success])

    slurm_instance(submit_host: 'owens.osc.edu').info_historic
  end

  def test_time_format_is_not_set_for_sbatch
    Open3.expects(:capture3).with { |env, cmd, *| cmd == 'sbatch' && !env.key?('SLURM_TIME_FORMAT') }.returns(['job.123', '', exit_success])

    slurm_instance.submit(build_script(copy_environment: true))
  end

  def test_sacct_from_and_to_times_are_relative
    Time.stubs(:now).returns(Time.utc(2026, 2, 11, 12, 0, 0))
    Open3.expects(:capture3).with do |_env, cmd, *args|
      cmd == 'sacct' && args.each_cons(2).include?(['-S', 'now-86400']) && args.each_cons(2).include?(['-E', 'now'])
    end.returns(['', '', exit_success])

    slurm_instance.info_historic(opts: { from: Time.utc(2026, 2, 10, 12, 0, 0), to: DateTime.new(2026, 2, 11, 13, 0, 0, '+01:00') })
  end

  def test_sacct_from_and_to_strings_are_passed_as_is
    Open3.expects(:capture3).with do |_env, cmd, *args|
      cmd == 'sacct' && args.each_cons(2).include?(['-S', '2026-02-10']) && args.each_cons(2).include?(['-E', '2026-02-11T12:00:00'])
    end.returns(['', '', exit_success])

    slurm_instance.info_historic(opts: { from: '2026-02-10', to: '2026-02-11T12:00:00' })
  end
end
