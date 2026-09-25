require 'test_helper'
require 'ood_core/job/adapters/slurm'

class TestSlurm < Minitest::Test
  include TestHelper

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
      {}, 'sacctmgr', '-nP', 'show', 'users', 'withassoc', 'format=account,qos', 'where', 'user=me', 'cluster=owens', stdin_data: ''
    ).returns([File.read('spec/fixtures/output/slurm/sacctmgr_show_accts_owens.txt'), '', exit_success])

    accounts = adapter.accounts
    assert_equal(accounts.map(&:name), ["pzs1124", "pzs1118", "pzs1117", "pzs1010", "pzs0715", "pzs0714", "pde0006", "pas2051", "pas1871", "pas1754", "pas1604"])
    accounts.each { |account| assert_equal(account.cluster, 'owens') }
  end

  def test_cluster_info
    adapter = slurm_instance
    Open3.stubs(:capture3).with({}, 'sinfo', '-aho %F/%C', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/sinfo_fc.txt'), '', exit_success])
    Open3.stubs(:capture3).with({}, 'sinfo', '-ahNO', 'nodehost:100,gres:512,gresused:512,statelong', stdin_data: '')
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
    Open3.stubs(:capture3).with({}, 'sinfo', '-aho %F/%C', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/sinfo_fc_long_hostnames.txt'), '', exit_success])
    Open3.stubs(:capture3).with({}, 'sinfo', '-ahNO', 'nodehost:100,gres:512,gresused:512,statelong', stdin_data: '')
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
      {}, 'squeue', '--all', '--states=all', '--noconvert', '-O', "Account:\u001F,JobID:\u001F,BatchHost:\u001F,MinCpus:\u001F,NumCPUs:\u001F,MinTmpDisk:\u001F,NumNodes:\u001F,EndTime:\u001F,Dependency:\u001F,Feature:\u001F,ArrayJobID:\u001F,GroupName:\u001F,GroupID:\u001F,OverSubscribe:\u001F,Sockets:\u001F,JobArrayID:\u001F,Cores:\u001F,Name:\u001F,Threads:\u001F,Comment:\u001F,ArrayTaskID:\u001F,TimeLimit:\u001F,TimeLeft:\u001F,MinMemory:\u001F,TimeUsed:\u001F,ReqNodes:\u001F,NodeList:\u001F,Command:\u001F,Contiguous:\u001F,QOS:\u001F,Partition:\u001F,PriorityLong:\u001F,Reason:\u001F,StartTime:\u001F,StateCompact:\u001F,State:\u001F,UserName:\u001F,UserID:\u001F,Reservation:\u001F,SubmitTime:\u001F,WCKey:\u001F,Licenses:\u001F,ExcNodes:\u001F,CoreSpec:\u001F,Nice:\u001F,SchedNodes:\u001F,SCT:\u001F,WorkDir:\u001F,tres-alloc:\u001F,tres-per-node:\u001F,", stdin_data: ''
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
    Open3.stubs(:capture3).with({}, 'scontrol', 'show', 'part', '-o', stdin_data: '')
         .returns([File.read('spec/fixtures/output/slurm/owens_partitions.txt'), '', exit_success])

    queues = adapter.queues
    queue = queues.find { |q| q.name == 'dynamic' }

    refute_nil(queue)
    assert_equal({}, queue.tres)
  end

  # unit tests for the parser

  def test_gpu_types_from_tres_typed_entry
    tres = 'cpu=17,mem=64G,node=1,billing=17,gres/gpu=1,gres/gpu:a100=1'

    assert_equal({ 'a100' => 1 }, OodCore::Job::Adapters::Slurm.gpu_types_from_tres(tres))
  end

  def test_gpu_types_from_tres_untyped_entry_has_no_type
    tres = 'cpu=21,mem=84567M,node=1,billing=21,gres/gpu=2'

    assert_equal({}, OodCore::Job::Adapters::Slurm.gpu_types_from_tres(tres))
  end

  def test_gpu_types_from_tres_multiple_types
    tres = 'cpu=8,gres/gpu=3,gres/gpu:a100=2,gres/gpu:v100=1,node=1'

    assert_equal({ 'a100' => 2, 'v100' => 1 },
                  OodCore::Job::Adapters::Slurm.gpu_types_from_tres(tres))
  end

  def test_gpu_types_from_tres_without_gres_prefix
    assert_equal({ 'a100' => 4 },
                  OodCore::Job::Adapters::Slurm.gpu_types_from_tres('cpu=8,gpu:a100=4,node=1'))
  end

  def test_gpu_types_from_tres_no_gpus
    assert_equal({}, OodCore::Job::Adapters::Slurm.gpu_types_from_tres('cpu=33,mem=128G,node=1'))
  end

  def test_gpu_types_from_tres_handles_nil_and_null
    assert_equal({}, OodCore::Job::Adapters::Slurm.gpu_types_from_tres(nil))
    assert_equal({}, OodCore::Job::Adapters::Slurm.gpu_types_from_tres('(null)'))
    assert_equal({}, OodCore::Job::Adapters::Slurm.gpu_types_from_tres(''))
  end

  # integration test through the squeue path

  def test_info_all_populates_gpu_types
    adapter = slurm_instance
    squeue_fields_arg = "Account:\u001F,JobID:\u001F,BatchHost:\u001F,MinCpus:\u001F,NumCPUs:\u001F,MinTmpDisk:\u001F,NumNodes:\u001F,EndTime:\u001F,Dependency:\u001F,Feature:\u001F,ArrayJobID:\u001F,GroupName:\u001F,GroupID:\u001F,OverSubscribe:\u001F,Sockets:\u001F,JobArrayID:\u001F,Cores:\u001F,Name:\u001F,Threads:\u001F,Comment:\u001F,ArrayTaskID:\u001F,TimeLimit:\u001F,TimeLeft:\u001F,MinMemory:\u001F,TimeUsed:\u001F,ReqNodes:\u001F,NodeList:\u001F,Command:\u001F,Contiguous:\u001F,QOS:\u001F,Partition:\u001F,PriorityLong:\u001F,Reason:\u001F,StartTime:\u001F,StateCompact:\u001F,State:\u001F,UserName:\u001F,UserID:\u001F,Reservation:\u001F,SubmitTime:\u001F,WCKey:\u001F,Licenses:\u001F,ExcNodes:\u001F,CoreSpec:\u001F,Nice:\u001F,SchedNodes:\u001F,SCT:\u001F,WorkDir:\u001F,tres-alloc:\u001F,tres-per-node:\u001F,"
    Open3.stubs(:capture3).with(
      {}, 'squeue', '--all', '--states=all', '--noconvert', '-O', squeue_fields_arg, stdin_data: ''
    ).returns([File.read('spec/fixtures/output/slurm/squeue_gpu_types.txt'), '', exit_success])

    jobs = adapter.info_all

    typed   = jobs.find { |job| job.id == '7126159' }
    untyped = jobs.find { |job| job.id == '7126996' }
    no_gpu  = jobs.find { |job| job.id == '7126023' }

    # typed entry in tres-alloc gives us the model
    assert_equal({ 'a100' => 1 }, typed.gpu_types)
    # rollup only: a gpu count, but no type information
    assert_equal({}, untyped.gpu_types)
    # gpus comes from tres-per-node on this path, which is N/A for this job
    assert_equal(0, untyped.gpus)
    # no gpus at all
    assert_equal({}, no_gpu.gpu_types)
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
    Open3.stubs(:capture3).with({}, 'scontrol', 'show', 'part', '-o', stdin_data: '')
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

  def test_duration_in_seconds_with_days
    assert_equal(131_400, OodCore::Job::Adapters::Slurm.duration_in_seconds('1-12:30:00'))
  end

  def test_duration_in_seconds_hours_minutes_seconds
    assert_equal(45_000, OodCore::Job::Adapters::Slurm.duration_in_seconds('12:30:00'))
  end

  def test_duration_in_seconds_minutes_seconds
    assert_equal(1800, OodCore::Job::Adapters::Slurm.duration_in_seconds('30:00'))
  end

  def test_duration_in_seconds_with_nil
    assert_equal(0, OodCore::Job::Adapters::Slurm.duration_in_seconds(nil))
  end
end
