require 'ood_core'
require 'mocha/minitest'

module TestHelper

  # verify the keywords of an objects interface.
  # Example: given the interface - def foo(bar: nil)
  # veryify_keywords(object, :foo, [:bar])
  # to verify that the method foo takes only one keyword :bar.
  def veryify_keywords(object, method, keywords)
    parameters = object.method(method.to_sym).parameters
    actual_keywords = parameters.select do |key, _value|
      key.to_sym == :key
    end.map do |_key, value|
      value
    end.sort

    assert_equal(keywords.sort, actual_keywords)
  end

  def verify_args(object, method, num_of_args)
    parameters = object.method(method.to_sym).parameters
    actual_num_of_args = parameters.select do |key, _value|
      key.to_sym == :req || key.to_sym == :opt
    end.count

    assert_equal(actual_num_of_args, num_of_args)
  end

  def build_script(opts = {})
    OodCore::Job::Script.new(
      **{
        content: script_content
      }.merge(opts)
    )
  end

  def script_content
    "my job script"
  end

  def stub_submit(jobid = '123')
    Open3.stubs(:capture3).returns([jobid, '', exit_success])
  end

  def exit_success
    OpenStruct.new(:success? => true, :exitstatus => 0)
  end

  def stub_etc
    Etc.stubs(:getlogin).returns('me')
  end
end
