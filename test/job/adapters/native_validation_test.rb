require 'test_helper'
require 'ood_core/job/adapters/htcondor'

# Every adapter checks script.native's type before submitting, so a wrong type
# gets an error that says what's wrong instead of a TypeError from deep inside
# the adapter (ood_core#299).
class NativeValidationTest < Minitest::Test
  include TestHelper

  # Stops submit at validate_native, before anything talks to a scheduler
  class StoppedAtValidation < StandardError; end

  # adapter => [the types it accepts, a type it doesn't, whether it's required]
  ADAPTERS = {
    'slurm'       => [[Array], { a: 1 }, false],
    'pbspro'      => [[Array], { a: 1 }, false],
    'lsf'         => [[Array], { a: 1 }, false],
    'ccq'         => [[Array], { a: 1 }, false],
    'fujitsu_tcs' => [[Array], { a: 1 }, false],
    'psij'        => [[Array], { a: 1 }, false],
    'flux'        => [[Array], { a: 1 }, false],
    'torque'      => [[Array, Hash], 'a string', false],
    'sge'         => [[Array, String], { a: 1 }, false],
    'linux_host'  => [[Hash], ['--nodes', '1'], false],
    'systemd'     => [[Hash], ['--nodes', '1'], false],
    'htcondor'    => [[Hash], ['--nodes', '1'], false],
    'kubernetes'  => [[Hash], ['--nodes', '1'], true],
    'coder'       => [[Hash], ['--nodes', '1'], true]
  }.freeze

  ADAPTERS.each do |name, (types, wrong_native, required)|
    define_method("test_#{name}_checks_native_before_submitting") do
      adapter = build_adapter(name)
      script = OodCore::Job::Script.new(content: 'hostname', native: wrong_native)
      expected_args = required ? [script, *types, { required: true }] : [script, *types]
      adapter.expects(:validate_native).with(*expected_args).raises(StoppedAtValidation)

      assert_raises(StoppedAtValidation) { adapter.submit(script) }
    end

    define_method("test_#{name}_explains_a_wrong_native_type") do
      adapter = build_adapter(name)
      script = OodCore::Job::Script.new(content: 'hostname', native: wrong_native)

      error = assert_raises(OodCore::JobAdapterError) { adapter.submit(script) }
      assert_match(/adapter needs script.native to be/, error.message)
    end
  end

  def test_kubernetes_and_coder_explain_a_missing_native
    %w[kubernetes coder].each do |name|
      script = OodCore::Job::Script.new(content: 'hostname')

      error = assert_raises(OodCore::JobAdapterError) { build_adapter(name).submit(script) }
      assert_match(/needs script.native to be a hash .*, but it is not set/, error.message)
    end
  end

  def test_the_message_names_the_adapter_and_both_types
    script = OodCore::Job::Script.new(content: 'hostname', native: ['--nodes', '1'])

    error = assert_raises(OodCore::JobAdapterError) { build_adapter('kubernetes').submit(script) }
    assert_equal(
      'The Kubernetes adapter needs script.native to be a hash (YAML "key: value" lines), ' \
      'but it is a list (YAML "- item" lines). Check native: in the app\'s submit.yml.erb.',
      error.message
    )
  end

  def test_several_accepted_types_are_all_listed
    script = OodCore::Job::Script.new(content: 'hostname', native: 'a string')

    error = assert_raises(OodCore::JobAdapterError) { build_adapter('torque').submit(script) }
    assert_match(/to be a list \(YAML "- item" lines\) or hash \(YAML "key: value" lines\), but it is a string/, error.message)  end

  def test_accepted_types_pass
    adapter = build_adapter('torque')

    [nil, ['-l', 'nodes=1'], { headers: {} }].each do |native|
      script = OodCore::Job::Script.new(content: 'hostname', native: native)
      assert_nil(adapter.send(:validate_native, script, Array, Hash), native.inspect)
    end
  end

  private

  def build_adapter(name)
    case name
    when 'htcondor'
      # building it normally runs condor_version
      OodCore::Job::Adapters::HTCondor.new(htcondor: Object.new)
    when 'torque'
      OodCore::Job::Factory.build(adapter: name, host: 'torque.example', lib: '/dev/null', bin: '/dev/null')
    when 'linux_host'
      OodCore::Job::Factory.build(adapter: name, submit_host: 'host.example', singularity_image: '/dev/null')
    when 'systemd'
      OodCore::Job::Factory.build(adapter: name, submit_host: 'host.example')
    when 'coder'
      OodCore::Job::Factory.build(adapter: name, host: 'https://coder.example', token: 'token')
    else
      OodCore::Job::Factory.build(adapter: name)
    end
  end
end
