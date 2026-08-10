require 'test_helper'

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
      {}, 'squeue', '--all', '--states=all', '--noconvert', '-O', "Account:\u001F,JobID:\u001F,BatchHost:\u001F,MinCpus:\u001F,NumCPUs:\u001F,MinTmpDisk:\u001F,NumNodes:\u001F,EndTime:\u001F,Dependency:\u001F,Feature:\u001F,ArrayJobID:\u001F,GroupName:\u001F,GroupID:\u001F,OverSubscribe:\u001F,Sockets:\u001F,JobArrayID:\u001F,Cores:\u001F,Name:\u001F,Threads:\u001F,Comment:\u001F,ArrayTaskID:\u001F,TimeLimit:\u001F,TimeLeft:\u001F,MinMemory:\u001F,TimeUsed:\u001F,ReqNodes:\u001F,NodeList:\u001F,Command:\u001F,Contiguous:\u001F,QOS:\u001F,Partition:\u001F,PriorityLong:\u001F,Reason:\u001F,StartTime:\u001F,StateCompact:\u001F,State:\u001F,UserName:\u001F,UserID:\u001F,Reservation:\u001F,SubmitTime:\u001F,WCKey:\u001F,Licenses:\u001F,ExcNodes:\u001F,CoreSpec:\u001F,Nice:\u001F,SchedNodes:\u001F,SCT:\u001F,WorkDir:\u001F,tres-per-node:\u001F,", stdin_data: ''
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
end
