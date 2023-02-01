# frozen_string_literal: true

# QueueInfo is information about a given queue on a scheduler.
class OodCore::Job::QueueInfo

  include OodCore::DataFormatter

  # The name of the queue.
  attr_reader :name
  alias to_s name

  # The QoSes associated with this queue
  attr_reader :qos

  # The accounts that are allowed to use this queue.
  #
  # nil means ALL accounts are allowed.
  attr_reader :allow_accounts

  # The accounts that are not allowed to use this queue.
  attr_reader :deny_accounts

  def initialize(**opts)
    @name = opts.fetch(:name, 'unknown')
    @qos = opts.fetch(:qos, [])

    allow_accounts = opts.fetch(:allow_accounts, nil)
    @allow_accounts = if allow_accounts.nil?
                        nil
                      else
                        allow_accounts.compact.map { |acct| upcase_accounts? ? acct.to_s.upcase : acct }
                      end

    @deny_accounts = opts.fetch(:deny_accounts, []).compact.map do |acct|
      upcase_accounts? ? acct.to_s.upcase : acct
    end
  end

  def to_h
    instance_variables.map do |var|
      name = var.to_s.gsub('@', '').to_sym
      [name, send(name)]
    end.to_h
  end
end
