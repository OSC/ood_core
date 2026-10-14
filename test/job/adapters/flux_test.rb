require 'test_helper'
require 'ood_core/job/adapters/flux'

# Fixtures in spec/fixtures/output/flux are real `flux jobs --json` output
# from flux-core 0.89.0 (fluxrm/flux-sched container).
class TestFlux < Minitest::Test
  include TestHelper

  FIXTURES = 'spec/fixtures/output/flux'.freeze

  # A fixed user, so submit expectations don't depend on who runs the tests
  def setup
    user = OpenStruct.new(name: 'me', dir: '/home/me', shell: '/bin/bash')
    Etc.stubs(:getpwuid).returns(user)
  end

  SYSTEM_PATH = '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'.freeze

  # What a cleared environment gets back: the user from the user database,
  # and a system PATH
  def default_env_args
    ['--env=USER=me', '--env=LOGNAME=me', '--env=HOME=/home/me', '--env=SHELL=/bin/bash', "--env=PATH=#{SYSTEM_PATH}"]
  end

  def flux_instance(config = {})
    OodCore::Job::Factory.build({ adapter: 'flux' }.merge(config))
  end

  def fixture(name)
    File.read("#{FIXTURES}/#{name}")
  end

  def exit_failure
    OpenStruct.new(:success? => false, :exitstatus => 1)
  end

  # Expect one flux command, with the environment that comes with it
  def expect_flux(*args, stdout: '', stderr: '', success: true, stdin: '', env: {})
    status = success ? exit_success : exit_failure
    Open3.expects(:capture3)
         .with(env, 'flux', *args, stdin_data: stdin)
         .returns([stdout, stderr, status])
  end

  # The args every submit gets when the script sets nothing
  def default_submit_args
    ['batch', '-n', '1', '--env=-*', *default_env_args]
  end

  def shebang_content
    "#!/bin/bash\n#{script_content}"
  end

  # --- factory and capabilities ---

  def test_factory_builds_flux_adapter
    assert_instance_of(OodCore::Job::Adapters::Flux, flux_instance)
  end

  def test_submit_interface
    flux = flux_instance

    veryify_keywords(flux, :submit, [:after, :afterok, :afternotok, :afterany])
    verify_args(flux, :submit, 1)
  end

  def test_directive_prefix
    assert_equal('# flux:', flux_instance.directive_prefix)
  end

  def test_supports_dependencies_but_not_arrays
    flux = flux_instance

    assert(flux.supports_job_dependencies?)
    refute(flux.supports_job_arrays?)
  end

  # --- job ids ---

  # Pairs taken from the same `flux jobs --json` records: "jobid" vs "id"
  def test_f58_ids_decode_to_decimal
    {
      "ƒiFkbMhFM" => '91088924704768',
      "ƒiFsPiQD5" => '91093387444224',
      "ƒiFxrykWs" => '91096977768448',
      "ƒiHP9Htes" => '91150983626752'
    }.each do |f58, decimal|
      assert_equal(decimal, OodCore::Job::Adapters::Flux::JobId.to_decimal(f58))
    end
  end

  def test_ascii_f58_prefix_decodes
    assert_equal('91088924704768', OodCore::Job::Adapters::Flux::JobId.to_decimal("fiFkbMhFM\n"))
  end

  def test_f58_decodes_from_binary_output
    raw = "ƒiFkbMhFM\n".b

    assert_equal('91088924704768', OodCore::Job::Adapters::Flux::JobId.to_decimal(raw))
  end

  def test_decimal_id_passes_through
    assert_equal('91088924704768', OodCore::Job::Adapters::Flux::JobId.to_decimal("91088924704768\n"))
  end

  def test_garbage_id_raises
    assert_raises(OodCore::Job::Adapters::Flux::Batch::Error) do
      OodCore::Job::Adapters::Flux::JobId.to_decimal('not-a-job-id')
    end
  end

  # --- submit ---

  def test_submit_returns_decimal_id
    expect_flux(*default_submit_args, stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    assert_equal('91088924704768', flux_instance.submit(build_script))
  end

  def test_submit_with_hold
    expect_flux('batch', '--urgency=hold', '-n', '1', '--env=-*', *default_env_args, stdout: "ƒiFsPiQD5\n", stdin: shebang_content)

    assert_equal('91093387444224', flux_instance.submit(build_script(submit_as_hold: true)))
  end

  def test_submit_with_options
    script = build_script(
      workdir: '/home/fluxuser/work',
      job_name: 'my_job',
      input_path: '/tmp/in',
      output_path: '/tmp/out',
      error_path: '/tmp/err',
      queue_name: 'debug',
      accounting_id: 'pzs0715',
      wall_time: 3600,
      cores: 4
    )
    expect_flux(
      'batch',
      '--cwd', '/home/fluxuser/work',
      '--job-name', 'my_job',
      '--input', '/tmp/in',
      '--output', '/tmp/out',
      '--error', '/tmp/err',
      '-q', 'debug',
      '--bank', 'pzs0715',
      '-t', '3600s',
      '-n', '4',
      '--env=-*', *default_env_args,
      stdout: "ƒiFkbMhFM\n", stdin: shebang_content
    )

    flux_instance.submit(script)
  end

  def test_submit_with_start_time_is_relative
    now = Time.at(1_791_485_339)
    Time.stubs(:now).returns(now)
    expect_flux('batch', '-n', '1', '--begin-time', '+300s', '--env=-*', *default_env_args, stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script(start_time: now + 300))
  end

  def test_submit_with_start_time_in_the_past_starts_now
    now = Time.at(1_791_485_339)
    Time.stubs(:now).returns(now)
    expect_flux('batch', '-n', '1', '--begin-time', '+0s', '--env=-*', *default_env_args, stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script(start_time: now - 300))
  end

  def test_submit_with_dependencies
    expect_flux(
      'batch',
      '-n', '1',
      '--dependency=afterstart:1',
      '--dependency=afterok:2',
      '--dependency=afterok:3',
      '--dependency=afternotok:4',
      '--dependency=afterany:5',
      '--env=-*', *default_env_args,
      stdout: "ƒiFkbMhFM\n", stdin: shebang_content
    )

    flux_instance.submit(build_script, after: 1, afterok: [2, 3], afternotok: '4', afterany: [5])
  end

  def test_submit_with_job_environment_clears_submit_environment
    expect_flux('batch', '-n', '1', '--env=-*', *default_env_args, '--env=FOO=bar', '--env=BAZ=1', stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script(job_environment: { 'FOO' => 'bar', 'BAZ' => 1 }))
  end

  # Checked against flux-core 0.89.0: with --env=-* the job only sees the
  # variables Flux sets itself plus what we pass, not even HOME, USER or
  # PATH, and a #!/bin/bash -l login shell doesn't bring PATH back.
  def test_submit_clears_environment_and_sets_defaults
    expect_flux(*default_submit_args, stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script)
  end

  def test_job_environment_overrides_defaults
    expect_flux(
      'batch', '-n', '1', '--env=-*',
      '--env=USER=me', '--env=LOGNAME=me', '--env=SHELL=/bin/bash',
      '--env=HOME=/scratch/me', '--env=PATH=/opt/sw/bin',
      stdout: "ƒiFkbMhFM\n", stdin: shebang_content
    )

    flux_instance.submit(build_script(job_environment: { HOME: '/scratch/me', 'PATH' => '/opt/sw/bin' }))
  end

  # So `flux run` resolves inside the job at sites that install flux elsewhere
  def test_configured_bin_goes_first_in_path
    expect_flux_bin = '/opt/flux/bin/flux'
    expected_args = [
      'batch', '-n', '1', '--env=-*',
      '--env=USER=me', '--env=LOGNAME=me', '--env=HOME=/home/me', '--env=SHELL=/bin/bash',
      "--env=PATH=/opt/flux/bin:#{SYSTEM_PATH}"
    ]
    Open3.expects(:capture3)
         .with({}, expect_flux_bin, *expected_args, stdin_data: shebang_content)
         .returns(["ƒiFkbMhFM\n", '', exit_success])

    flux_instance(bin: '/opt/flux/bin').submit(build_script)
  end

  def test_submit_with_copy_environment_keeps_submit_environment
    expect_flux('batch', '-n', '1', '--env=FOO=bar', stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script(copy_environment: true, job_environment: { 'FOO' => 'bar' }))
  end

  # flux batch refuses to submit without a size:
  #   flux-batch: ERROR: Number of slots to allocate must be specified
  def test_submit_without_size_defaults_to_one_slot
    expect_flux('batch', '-n', '1', '--env=-*', *default_env_args, stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script)
  end

  def test_submit_with_native_nodes_skips_default_size
    expect_flux('batch', '--env=-*', *default_env_args, '-N', '2', '--exclusive', stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script(native: ['-N', '2', '--exclusive']))
  end

  def test_submit_with_native_size_forms_skip_default_size
    ['-N2', '-n', '-n4', '--nodes=2', '--nslots=4', '--nodes', '--nslots'].each do |size_arg|
      expect_flux('batch', '--env=-*', *default_env_args, size_arg, stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

      flux_instance.submit(build_script(native: [size_arg]))
    end
  end

  def test_submit_with_unrelated_native_args_keeps_default_size
    expect_flux('batch', '-n', '1', '--env=-*', *default_env_args, '--exclusive', stdout: "ƒiFkbMhFM\n", stdin: shebang_content)

    flux_instance.submit(build_script(native: ['--exclusive']))
  end

  # flux batch rejects a script without a shebang (flux-core 0.89.0):
  #   flux-batch: ERROR: batch does not appear to start with '#!'
  def test_submit_adds_shebang_when_missing
    expect_flux(*default_submit_args, stdout: "ƒiFkbMhFM\n", stdin: "#!/bin/bash\nhostname")

    flux_instance.submit(build_script(content: 'hostname'))
  end

  def test_submit_with_shell_path
    expect_flux(*default_submit_args, stdout: "ƒiFkbMhFM\n", stdin: "#!/bin/zsh\n#{script_content}")

    flux_instance.submit(build_script(shell_path: '/bin/zsh'))
  end

  def test_submit_keeps_existing_shebang
    content = "#!/usr/bin/env bash\nhostname"
    expect_flux(*default_submit_args, stdout: "ƒiFkbMhFM\n", stdin: content)

    flux_instance.submit(build_script(content: content))
  end

  def test_submit_job_array_raises
    Open3.expects(:capture3).never

    assert_raises(OodCore::JobAdapterError) do
      flux_instance.submit(build_script(job_array_request: '1-10'))
    end
  end

  def test_submit_error_raises_adapter_error
    expect_flux(*default_submit_args, stderr: 'flux-batch: ERROR: queue not found', success: false, stdin: shebang_content)

    error = assert_raises(OodCore::JobAdapterError) { flux_instance.submit(build_script) }
    assert_match(/queue not found/, error.message)
  end

  # --- info ---

  def test_info_running_job
    expect_flux('jobs', '--json', '91088924704768', stdout: fixture('jobs_running.json'))

    info = flux_instance.info('91088924704768')

    assert_equal('91088924704768', info.id)
    assert_equal(:running, info.status.to_sym)
    assert_equal(['3db47f546663'], info.allocated_nodes.map(&:name))
    assert_equal('sleep', info.job_name)
    assert_equal('fluxuser', info.job_owner)
    assert_equal(10, info.procs)
    assert_equal(0, info.wallclock_time)
    assert_nil(info.wallclock_limit)
    assert_equal(Time.at(1_791_485_339), info.submission_time)
    assert_equal(Time.at(1_791_485_339), info.dispatch_time)
    assert_equal("ƒiFkbMhFM", info.native[:jobid])
  end

  def test_info_held_job
    expect_flux('jobs', '--json', '91093387444224', stdout: fixture('jobs_held.json'))

    info = flux_instance.info('91093387444224')

    assert_equal(:queued_held, info.status.to_sym)
    assert_equal(1, info.allocated_nodes.size)
    assert_nil(info.procs)
    assert_nil(info.wallclock_time)
    assert_nil(info.dispatch_time)
  end

  def test_info_pending_job
    expect_flux('jobs', '--json', '91096977768448', stdout: fixture('jobs_pending.json'))

    info = flux_instance.info('91096977768448')

    assert_equal(:queued, info.status.to_sym)
    assert_equal('sh', info.job_name)
  end

  def test_info_pending_job_with_time_limit
    expect_flux('jobs', '--json', '91150983626752', stdout: fixture('jobs_pending_time_limit.json'))

    assert_equal(5, flux_instance.info('91150983626752').wallclock_limit)
  end

  def test_info_canceled_job
    expect_flux('jobs', '--json', '91088924704768', stdout: fixture('jobs_canceled.json'))

    info = flux_instance.info('91088924704768')

    assert_equal(:completed, info.status.to_sym)
    assert_equal(18, info.wallclock_time)
    assert_equal('CANCELED', info.native[:result])
  end

  def test_info_unknown_job_is_completed
    expect_flux('jobs', '--json', '999999', stderr: fixture('jobs_unknown.txt'), success: false)

    info = flux_instance.info('999999')

    assert_equal('999999', info.id)
    assert_equal(:completed, info.status.to_sym)
  end

  # OOD hosts often run with a C locale, so Open3 hands back US-ASCII strings
  def test_info_parses_utf8_output_in_c_locale
    job = JSON.parse(fixture('jobs_running.json'))
    job['name'] = "café"
    raw = job.to_json.b.force_encoding(Encoding::US_ASCII)
    expect_flux('jobs', '--json', '91088924704768', stdout: raw)

    assert_equal("café", flux_instance.info('91088924704768').job_name)
  end

  def test_info_other_error_raises
    expect_flux('jobs', '--json', '1', stderr: 'flux-jobs: ERROR: Unable to connect to Flux', success: false)

    assert_raises(OodCore::JobAdapterError) { flux_instance.info('1') }
  end

  def test_status
    expect_flux('jobs', '--json', '91093387444224', stdout: fixture('jobs_held.json'))

    assert_equal(:queued_held, flux_instance.status('91093387444224').to_sym)
  end

  # Multi-job output is wrapped in {"jobs": [...]} (checked against
  # `flux jobs --json -A` on flux-core 0.89.0). The jobs here are assembled
  # from single-job fixtures; replace with recorded output once
  # scheduler_recordings has a Flux backend.
  def test_info_all
    jobs = { jobs: [JSON.parse(fixture('jobs_running.json')), JSON.parse(fixture('jobs_held.json'))] }
    expect_flux('jobs', '--json', '-A', stdout: jobs.to_json)

    infos = flux_instance.info_all

    assert_equal(['91088924704768', '91093387444224'], infos.map(&:id))
    assert_equal([:running, :queued_held], infos.map { |i| i.status.to_sym })
  end

  def test_info_all_with_no_jobs
    expect_flux('jobs', '--json', '-A', stdout: '{"jobs": []}')

    assert_equal([], flux_instance.info_all)
  end

  def test_info_where_owner
    jobs = { jobs: [JSON.parse(fixture('jobs_running.json'))] }
    expect_flux('jobs', '--json', '-u', 'fluxuser', stdout: jobs.to_json)

    infos = flux_instance.info_where_owner('fluxuser')

    assert_equal(['fluxuser'], infos.map(&:job_owner))
  end

  # --- hold, release, delete ---

  def test_hold
    expect_flux('job', 'urgency', '91088924704768', 'hold')

    flux_instance.hold('91088924704768')
  end

  def test_release
    expect_flux('job', 'urgency', '91088924704768', 'default')

    flux_instance.release('91088924704768')
  end

  def test_delete
    expect_flux('cancel', '91088924704768')

    flux_instance.delete('91088924704768')
  end

  # Real `flux cancel 999999` stderr. The id comes back in F58, so the
  # message isn't ASCII, and a C locale hands it over as US-ASCII.
  def test_delete_unknown_job_is_ignored
    stderr = fixture('cancel_unknown.txt').b.force_encoding(Encoding::US_ASCII)
    expect_flux('cancel', '999999', stderr: stderr, success: false)

    flux_instance.delete('999999')
  end

  def test_delete_other_error_raises
    expect_flux('cancel', '1', stderr: 'flux-cancel: ERROR: Permission denied', success: false)

    assert_raises(OodCore::JobAdapterError) { flux_instance.delete('1') }
  end

  # --- configuration ---

  def test_flux_uri_is_passed_in_environment
    uri = 'local:///run/flux/local'
    expect_flux('jobs', '--json', '91088924704768', stdout: fixture('jobs_running.json'), env: { 'FLUX_URI' => uri })

    flux_instance(flux_uri: uri).info('91088924704768')
  end

  def test_bin_overrides
    Open3.expects(:capture3)
         .with({}, '/opt/flux/bin/flux', 'cancel', '1', stdin_data: '')
         .returns(['', '', exit_success])

    flux_instance(bin_overrides: { 'flux' => '/opt/flux/bin/flux' }).delete('1')
  end

  def test_submit_host_wraps_in_ssh
    Open3.expects(:capture3).with do |env, cmd, *args|
      positional = args.reject { |arg| arg.is_a?(Hash) }
      env == {} && cmd == 'ssh' && positional.include?('login.example.edu') && positional.last(3) == ['flux', 'cancel', '1']
    end.returns(['', '', exit_success])

    flux_instance(submit_host: 'login.example.edu').delete('1')
  end

  # --- nodelists ---

  def test_expand_nodelist
    flux = flux_instance

    assert_equal(['node1', 'node2', 'node3', 'node7'], flux.send(:expand_nodelist, 'node[1-3,7]'))
    assert_equal(['a', 'b01', 'b02'], flux.send(:expand_nodelist, 'a,b[01-02]'))
    assert_equal([], flux.send(:expand_nodelist, nil))
  end
end
