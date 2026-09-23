require 'test_helper'

class QueueInfoTest < Minitest::Test
  include TestHelper

  def test_defaults
    queue = OodCore::Job::QueueInfo.new

    assert_equal('unknown', queue.name)
    assert_equal([], queue.allow_qos)
    assert_equal([], queue.deny_qos)
    assert_nil(queue.allow_accounts)
    assert_equal([], queue.deny_accounts)
    assert_equal({}, queue.tres)
    assert_nil(queue.min_nodes)
    assert_nil(queue.max_nodes)
    assert_nil(queue.max_cpus)
    assert_nil(queue.max_time)
  end
end
