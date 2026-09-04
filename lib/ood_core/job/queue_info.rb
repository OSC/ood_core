# frozen_string_literal: true

# QueueInfo is information about a given queue on a scheduler.
class OodCore::Job::QueueInfo

  include OodCore::DataFormatter

  # The name of the queue.
  attr_reader :name
  alias to_s name

  # The QoSes associated with this queue
  attr_reader :allow_qos
  attr_reader :deny_qos

  # The accounts that are allowed to use this queue.
  #
  # nil means ALL accounts are allowed.
  attr_reader :allow_accounts

  # The accounts that are not allowed to use this queue.
  attr_reader :deny_accounts

  # An Hash of Trackable Resources and their values.
  attr_reader :tres

  # The minimum nodes a job can request for this queue.
  # Defaults to nil.
  # @return [Integer]
  attr_reader :min_nodes

  # The maximum nodes a job can request for this queue.
  # Defaults to nil. Returns nil if unlimited.
  # @return [Integer]
  attr_reader :max_nodes

  # The maximum CPUs the job can request. Note these are
  # maximum per node.
  # Defaults to nil. Returns nil if unlimited.
  # @return [Integer]
  attr_reader :max_cpus

  # The maximum number of time in seconds the job can request.
  # Defaults to nil. Returns nil if unlimited.
  # @return [Integer]
  attr_reader :max_time

  def initialize(**opts)
    @name = opts.fetch(:name, 'unknown')
    @allow_qos = opts.fetch(:allow_qos, [])
    @deny_qos = opts.fetch(:deny_qos, [])
    @tres = opts.fetch(:tres, {})

    # these options preserve nil
    @min_nodes = opts[:min_nodes] && opts[:min_nodes].to_i
    @max_nodes = opts[:max_nodes] && opts[:max_nodes].to_i
    @max_cpus = opts[:max_cpus] && opts[:max_cpus].to_i
    @max_time = opts[:max_time] && opts[:max_time].to_i

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

  def gpu?
    tres.keys.any? { |name| name.to_s.match?(%r{^gres/gpu($|:)}i) }
  end

  def allow_all_qos?
    allow_qos.empty? && deny_qos.empty?
  end
end
