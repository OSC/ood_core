require 'singleton'
 module DRMAA
  # The one and only connection with DRMAA
  # Attempting to instantiate a DRMAA::Session more than once causes it to crash
  class SessionSingleton < DRMAA::Session
    include Singleton
  end
   DRMMA_TO_OOD_STATE_MAP = {
    DRMAA::STATE_UNDETERMINED          => :undetermined,
    DRMAA::STATE_QUEUED_ACTIVE         => :queued,
    DRMAA::STATE_SYSTEM_ON_HOLD        => :queued_held,
    DRMAA::STATE_USER_ON_HOLD          => :queued_held,
    DRMAA::STATE_USER_SYSTEM_ON_HOLD   => :queued_held,
    DRMAA::STATE_RUNNING               => :running,
    DRMAA::STATE_SYSTEM_SUSPENDED      => :suspended,
    DRMAA::STATE_USER_SUSPENDED        => :suspended,
    DRMAA::STATE_USER_SYSTEM_SUSPENDED => :suspended,
    DRMAA::STATE_DONE                  => :completed,
    DRMAA::STATE_FAILED                => :completed
  }
end