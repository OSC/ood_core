class OodCore::Job::Adapters::Torque::FFI
  # The root exception class that all PBS-specific exceptions inherit from
  class Error < StandardError; end

  # Unknown job ID error
  class UnkjobidError < Error; end

  # Undefined attribute
  class NoattrError < Error; end

  # Cannot set attribute, read only or insufficient permission
  class AttrroError < Error; end

  # Invalid request
  class IvalreqError < Error; end

  # Unknown request
  class UnkreqError < Error; end

  # Too many submit retries
  class ToomanyError < Error; end

  # Unauthorized Request
  class PermError < Error; end

  # trqauthd unable to authenticate
  class IffNotFoundError < Error; end

  # Munge executable not found, unable to authenticate
  class MungeNotFoundError < Error; end

  # Access from host not allowed, or unknown host
  class BadhostError < Error; end

  # Job with requested ID already exists
  class JobexistError < Error; end

  # System error
  class SystemError < Error; end

  # PBS server internal error
  class InternalError < Error; end

  # Dependent parent job currently in routing queue
  class RegrouteError < Error; end

  # Unknown/illegal signal name
  class UnksigError < Error; end

  # Illegal attribute or resource value for
  class BadatvalError < Error; end

  # Cannot modify attribute while job running
  class ModatrrunError < Error; end

  # Request invalid for state of job
  class BadstateError < Error; end

  # Unknown queue
  class UnkqueError < Error; end

  # Invalid credential
  class BadcredError < Error; end

  # Expired credential
  class ExpiredError < Error; end

  # Queue is not enabled
  class QunoenbError < Error; end

  # Access to queue is denied
  class QacessError < Error; end

  # Bad UID for job execution
  class BaduserError < Error; end

  # Job routing over too many hops
  class HopcountError < Error; end

  # Queue already exists
  class QueexistError < Error; end

  # Incompatible type
  class AttrtypeError < Error; end

  # Cannot delete busy queue
  class QuebusyError < Error; end

  # Queue name too long
  class QuenbigError < Error; end

  # No support for requested service
  class NosupError < Error; end

  # Cannot enable queue, incomplete definition
  class QuenoenError < Error; end

  # Batch protocol error
  class ProtocolError < Error; end

  # Bad attribute list structure
  class BadatlstError < Error; end

  # No free connections
  class NoconnectsError < Error; end

  # No server specified
  class NoserverError < Error; end

  # Unknown resource type
  class UnkrescError < Error; end

  # Job exceeds queue resource limits
  class ExcqrescError < Error; end

  # No default queue specified
  class QuenodfltError < Error; end

  # Job is not rerunnable
  class NorerunError < Error; end

  # Job rejected by all possible destinations (check syntax, queue resources, …)
  class RouterejError < Error; end

  # Time in Route Queue Expired
  class RouteexpdError < Error; end

  # Execution server rejected request
  class MomrejectError < Error; end

  # (qsub) cannot access script file
  class BadscriptError < Error; end

  # Stage-in of files failed
  class StageinError < Error; end

  # Resource temporarily unavailable
  class RescunavError < Error; end

  # Bad GID for job execution
  class BadgrpError < Error; end

  # Maximum number of jobs already in queue
  class MaxquedError < Error; end

  # Checkpoint busy, may retry
  class CkpbsyError < Error; end

  # Resource limit exceeds allowable
  class ExlimitError < Error; end

  # Invalid Account
  class BadacctError < Error; end

  # Job already in exit state
  class AlrdyexitError < Error; end

  # Job files not copied
  class NocopyfileError < Error; end

  # Unknown job id after clean init
  class CleanedoutError < Error; end

  # No master found for sync job set
  class NosyncmstrError < Error; end

  # Invalid Job Dependency
  class BaddependError < Error; end

  # Duplicate entry in list
  class DuplistError < Error; end

  # Bad DIS based Request Protocol
  class DisprotoError < Error; end

  # Cannot execute at specified host because of checkpoint or stagein files
  class ExecthereError < Error; end

  # Sister rejected
  class SisrejectError < Error; end

  # Sister could not communicate
  class SiscommError < Error; end

  # Request not allowed: Server shutting down
  class SvrdownError < Error; end

  # Not all tasks could checkpoint
  class CkpshortError < Error; end

  # Unknown node
  class UnknodeError < Error; end

  # Unknown node-attribute
  class UnknodeatrError < Error; end

  # Server has no node list
  class NonodesError < Error; end

  # Node name is too big
  class NodenbigError < Error; end

  # Node name already exists
  class NodeexistError < Error; end

  # Illegal value for
  class BadndatvalError < Error; end

  # Mutually exclusive values for
  class MutualexError < Error; end

  # Modification failed for
  class GmoderrError < Error; end

  # Server could not connect to MOM
  class NorelymomError < Error; end

  # No time-share node available
  class NotsnodeError < Error; end

  # Wrong job type
  class JobtypeError < Error; end

  # Bad ACL entry in host list
  class BadaclhostError < Error; end

  # Maximum number of jobs already in queue for user
  class MaxuserquedError < Error; end

  # Bad type in disallowedTypes list
  class BaddisallowtypeError < Error; end

  # Queue does not allow interactive jobs
  class NointeractiveError < Error; end

  # Queue does not allow batch jobs
  class NobatchError < Error; end

  # Queue does not allow rerunable jobs
  class NorerunableError < Error; end

  # Queue does not allow nonrerunable jobs
  class NononrerunableError < Error; end

  # Unknown Array ID
  class UnkarrayidError < Error; end

  # Bad Job Array Request
  class BadArrayReqError < Error; end

  # Bad data reading job array from file
  class BadArrayDataError < Error; end

  # Time out
  class TimeoutError < Error; end

  # Job not found
  class JobnotfoundError < Error; end

  # Queue does not allow fault tolerant jobs
  class NofaulttolerantError < Error; end

  # Queue does not allow fault intolerant jobs
  class NofaultintolerantError < Error; end

  # Queue does not allow job arrays
  class NojobarraysError < Error; end

  # Request was relayed to a MOM
  class RelayedToMomError < Error; end

  # Error allocating memory - out of memory
  class MemMallocError < Error; end

  # Error allocating controling mutex (lock/unlock)
  class MutexError < Error; end

  # Error setting thread attributes
  class ThreadattrError < Error; end

  # Error creating thread
  class ThreadError < Error; end

  # Error in socket select
  class SelectError < Error; end

  # Unable to get connection to socket
  class SocketFaultError < Error; end

  # Error writing data to socket
  class SocketWriteError < Error; end

  # Error reading data from socket
  class SocketReadError < Error; end

  # Socket close detected
  class SocketCloseError < Error; end

  # Error listening on socket
  class SocketListenError < Error; end

  # Invalid auth type in request
  class AuthInvalidError < Error; end

  # This functionality is not yet implemented
  class NotImplementedError < Error; end

  # Queue is currently not available
  class QuenotavailableError < Error; end

  # tmpdir owned by another user
  class TmpdiffownerError < Error; end

  # tmpdir exists but is not a directory
  class TmpnotdirError < Error; end

  # tmpdir cannot be named for job
  class TmpnonameError < Error; end

  # Cannot open demux sockets
  class CantopensocketError < Error; end

  # Cannot send join job to all sisters
  class CantcontactsistersError < Error; end

  # Cannot create tmpdir for job
  class CantcreatetmpdirError < Error; end

  # Mom is down, cannot run job
  class BadmomstateError < Error; end

  # Socket information is not accessible
  class SocketInformationError < Error; end

  # Data on socket does not process correctly
  class SocketDataError < Error; end

  # Client is not allowed/trusted
  class ClientInvalidError < Error; end

  # Premature End of File
  class PrematureEofError < Error; end

  # Error saving file
  class CanNotSaveFileError < Error; end

  # Error opening file
  class CanNotOpenFileError < Error; end

  # Error writing file
  class CanNotWriteFileError < Error; end

  # Job file corrupt
  class JobFileCorruptError < Error; end

  # Job can not be rerun
  class JobRerunError < Error; end

  # Can not establish connection
  class ConnectError < Error; end

  # Job function must be temporarily delayed
  class JobworkdelayError < Error; end

  # Parameter of function was invalid
  class BadParameterError < Error; end

  # Continue processing on job. (Not an error)
  class ContinueError < Error; end

  # Current sub state does not allow trasaction.
  class JobsubstateError < Error; end

  # Error moving file
  class CanNotMoveFileError < Error; end

  # Job is being recycled
  class JobRecycledError < Error; end

  # Job is already in destination queue.
  class JobAlreadyInQueueError < Error; end

  # Mutex is NULL or otherwise invalid
  class InvalidMutexError < Error; end

  # The mutex is already locked by this object
  class MutexAlreadyLockedError < Error; end

  # The mutex has already been unlocked by this object
  class MutexAlreadyUnlockedError < Error; end

  # Command syntax invalid
  class InvalidSyntaxError < Error; end

  # A node is down. Check the MOM and host
  class NodeDownError < Error; end

  # Could not connect to batch server
  class ServerNotFoundError < Error; end

  # Server busy. Currently no available threads
  class ServerBusyError < Error; end
end
