# frozen_string_literal: true

# ReservationInfo is information about a reservation on a scheduler.
class OodCore::Job::ReservationInfo

  include OodCore::DataFormatter

  # The name of the reservation.
  attr_reader :name
  alias to_s name

  # The cluster this reservation comes from.
  attr_reader :cluster

  # The state of the reservation, like ACTIVE or INACTIVE.
  attr_reader :state

  # The time the reservation starts. Returns nil if unknown.
  # @return [Time]
  attr_reader :start_time

  # The time the reservation ends. Returns nil if unknown.
  # @return [Time]
  attr_reader :end_time

  # The partition the reservation is in. Returns nil if it has none.
  attr_reader :partition

  # The flags set on the reservation, like MAINT or SPEC_NODES.
  attr_reader :flags

  # The users that are allowed to use this reservation.
  #
  # nil means the reservation does not restrict users.
  attr_reader :allow_users

  # The users that are not allowed to use this reservation.
  attr_reader :deny_users

  # The groups that are allowed to use this reservation.
  #
  # nil means the reservation does not restrict groups.
  attr_reader :allow_groups

  # The accounts that are allowed to use this reservation.
  #
  # nil means the reservation does not restrict accounts.
  attr_reader :allow_accounts

  # The accounts that are not allowed to use this reservation.
  attr_reader :deny_accounts

  def initialize(**opts)
    @name = opts.fetch(:name, 'unknown')
    @cluster = opts.fetch(:cluster, nil)
    @state = opts.fetch(:state, nil)
    @start_time = opts.fetch(:start_time, nil)
    @end_time = opts.fetch(:end_time, nil)
    @partition = opts.fetch(:partition, nil)
    @flags = opts.fetch(:flags, [])

    @allow_users = opts.fetch(:allow_users, nil)
    @deny_users = opts.fetch(:deny_users, [])
    @allow_groups = opts.fetch(:allow_groups, nil)

    allow_accounts = opts.fetch(:allow_accounts, nil)
    @allow_accounts = allow_accounts&.compact&.map { |acct| format_account(acct) }
    @deny_accounts = opts.fetch(:deny_accounts, []).compact.map { |acct| format_account(acct) }
  end

  def to_h
    instance_variables.map do |var|
      name = var.to_s.gsub('@', '').to_sym
      [name, send(name)]
    end.to_h
  end

  private

  def format_account(account)
    upcase_accounts? ? account.to_s.upcase : account
  end
end
