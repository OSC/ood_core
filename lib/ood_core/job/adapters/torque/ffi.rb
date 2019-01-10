require 'ffi'

# An interface to the C-library of Torque
class OodCore::Job::Adapters::Torque::FFI

  extend ::FFI::Library

  # @!attribute [rw] self.pbs_errno
  #   The internal PBS error number
  #     int pbs_errno
  #   @return [Fixnum] pbs error number

  # @!attribute [r] self.pbs_server
  #   The PBS server name
  #     char *pbs_server
  #   @return [String] pbs server name

  # @!method self.pbs_strerror(errno)
  #   Generates PBS error string from given error number
  #     char *pbs_strerror(int errno)
  #   @param errno [Fixnum] pbs error number
  #   @return [String] pbs error string

  # @!method self.pbs_default
  #   Default PBS server name
  #     char *pbs_default(void)
  #   @see http://linux.die.net/man/3/pbs_default
  #   @return [String] default pbs server name

  # @!method self.pbs_connect(server)
  #   Connect to PBS batch server
  #     int pbs_connect(char *server)
  #   @see http://linux.die.net/man/3/pbs_connect
  #   @param server [String] name of pbs server
  #   @return [Fixnum] connection identifier

  # @!method self.pbs_disconnect(connect)
  #   Disconnect from a PBS batch server
  #     int pbs_disconnect(int connect)
  #   @see http://linux.die.net/man/3/pbs_disconnect
  #   @param connect [Fixnum] connection identifier
  #   @return [Fixnum] exit status code

  # @!method self.pbs_deljob(connect, job_id, extend)
  #   Delete a PBS batch job
  #     int pbs_deljob(int connect, char *job_id, char *extend)
  #   @see http://linux.die.net/man/3/pbs_deljob
  #   @param connect [Fixnum] connection identifier
  #   @param job_id [String] the job id
  #   @param extend [String] implementation defined extensions
  #   @return [Fixnum] exit status code

  # @!method self.pbs_holdjob(connect, job_id, hold_type, extend)
  #   Place a hold on a PBS batch job
  #     int pbs_holdjob(int connect, char *job_id, char *hold_type, char *extend)
  #   @see http://linux.die.net/man/3/pbs_holdjob
  #   @param connect [Fixnum] connection identifier
  #   @param job_id [String] the job id
  #   @param hold_type [String] type of hold to be applied
  #   @param extend [String] implementation defined extensions
  #   @return [Fixnum] exit status code

  # @!method self.pbs_rlsjob(connect, job_id, hold_type, extend)
  #   Release a hold on a PBS batch job
  #     int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend)
  #   @see http://linux.die.net/man/3/pbs_rlsjob
  #   @param connect [Fixnum] connection identifier
  #   @param job_id [String] the job id
  #   @param hold_type [String] type of hold to be released
  #   @param extend [String] implementation defined extensions
  #   @return [Fixnum] exit status code

  # @!method self.pbs_statfree(stat)
  #   Free the memory allocated by {BatchStatus} object
  #     void pbs_statfree(struct batch_status *stat)
  #   @param stat [BatchStatus] the batch status object
  #   @return [void]

  # @!method self.pbs_statjob(connect, id, attrib, extend)
  #   Obtain status of PBS batch jobs
  #     batch_status * pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend)
  #   @see http://linux.die.net/man/3/pbs_statjob
  #   @param connect [Fixnum] connection identifier
  #   @param id [String] job or destination identifier
  #   @param attrib [Attrl] the attribute c-linked list object
  #   @param extend [String] implementation defined extensions
  #   @return [BatchStatus] c-linked list of batch status objects
  #   @note It is up to the user to free the space of the batch status objects

  # @!method self.pbs_statnode(connect, id, attrib, extend)
  #   Obtain status of PBS nodes
  #     batch_status * pbs_statnode(int connect, char *id, struct attrl *attrib, char *extend)
  #   @see http://linux.die.net/man/3/pbs_statnode
  #   @param connect [Fixnum] connection identifier
  #   @param id [String] name of a node or null string
  #   @param attrib [Attrl] the attribute c-linked list object
  #   @param extend [String] implementation defined extensions
  #   @return [BatchStatus] c-linked list of batch status objects
  #   @note It is up to the user to free the space of the batch status objects

  # @!method self.pbs_statque(connect, id, attrib, extend)
  #   Obtain status of PBS batch queues
  #     batch_status * pbs_statque(int connect, char *id, struct attrl *attrib, char *extend)
  #   @see http://linux.die.net/man/3/pbs_statque
  #   @param connect [Fixnum] connection identifier
  #   @param id [String] name of a queue or null string
  #   @param attrib [Attrl] the attribute c-linked list object
  #   @param extend [String] implementation defined extensions
  #   @return [BatchStatus] c-linked list of batch status objects
  #   @note It is up to the user to free the space of the batch status objects

  # @!method self.pbs_statserver(connect, attrib, extend)
  #   Obtain status of a PBS batch server
  #     batch_status * pbs_statserver(int connect, struct attrl *attrib, char *extend)
  #   @see http://linux.die.net/man/3/pbs_statserver
  #   @param connect [Fixnum] connection identifier
  #   @param attrib [Attrl] the attribute c-linked list object
  #   @param extend [String] implementation defined extensions
  #   @return [BatchStatus] c-linked list of batch status objects
  #   @note It is up to the user to free the space of the batch status objects

  # @!method self.pbs_selstat(connect, attrib, extend)
  #   Obtain status of selected PBS batch jobs
  #     batch_status * pbs_selstat(int connect, struct attropl *sel_list, char *extend)
  #   @see http://linux.die.net/man/3/pbs_selstat
  #   @param connect [Fixnum] connection identifier
  #   @param attrib [Attropl] the attribute operation c-linked list object
  #   @param extend [String] implementation defined extensions
  #   @return [BatchStatus] c-linked list of batch status objects
  #   @note It is up to the user to free the space of the batch status objects

  # @!method self.pbs_submit(connect, attrib, script, destination, extend)
  #   Submit a PBS batch job
  #     char *pbs_submit(int connect, struct attropl *attrib, char *script, char *destination, char *extend)
  #   @see http://linux.die.net/man/3/pbs_submit
  #   @param connect [Fixnum] connection identifier
  #   @param attrib [Attropl] the attribute operation c-linked list object
  #   @param script [String] the path to the script
  #   @param destination [String] the queue to send job to
  #   @param extend [String] implementation defined extensions
  #   @return [String] the job id

  # The path to the torque library file
  # @return [String] path to torque library
  def self.lib
    @lib
  end

  # Define torque methods using a supplied library
  # @param lib [#to_s, nil] path to library file
  # @return [void]
  def self.lib=(lib)
    @lib = lib ? lib.to_s : 'torque'

    # Set up FFI to use this library
    ffi_lib @lib

    attach_variable :pbs_errno, :int
    attach_variable :pbs_server, :string
    attach_function :pbs_strerror, [ :int ], :string
    attach_function :pbs_default, [], :string
    attach_function :pbs_connect, [ :string ], :int
    attach_function :pbs_disconnect, [ :int ], :int
    attach_function :pbs_deljob, [ :int, :string, :string ], :int
    attach_function :pbs_holdjob, [ :int, :string, :string, :string ], :int
    attach_function :pbs_rlsjob, [ :int, :string, :string, :string ], :int
    attach_function :pbs_statfree, [ BatchStatus.ptr ], :void
    attach_function :pbs_statjob, [ :int, :string, Attrl.ptr, :string ], BatchStatus.ptr
    attach_function :pbs_statnode, [ :int, :string, Attrl.ptr, :string ], BatchStatus.ptr
    attach_function :pbs_statque, [ :int, :string, Attrl.ptr, :string ], BatchStatus.ptr
    attach_function :pbs_statserver, [ :int, Attrl.ptr, :string ], BatchStatus.ptr
    attach_function :pbs_selstat, [ :int, Attropl.ptr, :string ], BatchStatus.ptr

    # FIXME: The space for the job_identifier string is allocated by
    # pbs_submit() and should be released via a call to free() when no longer
    # needed
    attach_function :pbs_submit, [ :int, Attropl.ptr, :string, :string, :string ], :string
  end

  # Check for any errors set in the errno
  # @return [void]
  def self.check_for_error
    errno = pbs_errno
    self.pbs_errno = 0  # reset error number
    raise_error(errno) if errno > 0
  end

  # For a given errno, raise the corresponding error with error message
  # @param errno [Fixnum] the error number
  # @raise [Error] if errno is not 0
  # @return [void]
  def self.raise_error(errno)
    raise (ERROR_CODES[errno] || PBS::Error), "#{pbs_strerror(errno)}"
  end

  #
  # Data structures defined in pbs_ifl.h
  #

  # Enum for Batch Operation
  BatchOp = enum(:set, :unset, :incr, :decr, :eq, :ne, :ge, :gt, :le, :lt, :dflt, :merge, :incr_old)

  # Struct for Attribute C-linked list
  class Attrl < ::FFI::Struct
    layout :next,     Attrl.ptr,        # pointer to next Attrl object
           :name,     :pointer,         # string for name of attribute
           :resource, :pointer,         # string for resource if this attribute is a resource
           :value,    :pointer,         # string for value of attribute
           :op,       BatchOp           # not used in an Attrl object

    # Given an array of attribute names convert it to {Attrl} C-linked list
    # @param list [Array<Symbol>] list of attribute names
    # @return [Attrl] generated attribute c-linked list object
    def self.from_list(list)
      attrl = nil
      prev = Attrl.new(::FFI::Pointer::NULL)
      list.each do |key|
        attrl = Attrl.new
        attrl[:name] = ::FFI::MemoryPointer.from_string(key.to_s)
        attrl[:next] = prev
        prev = attrl
      end
      attrl
    end

    # Convert to hash describing this linked list
    # @return [Hash] hash describing linked list
    def to_h
      attrl = self
      hash = {}
      until attrl.to_ptr.null?
        n = attrl[:name].read_string
        v = attrl[:value].read_string
        r = attrl[:resource].null? ? nil : attrl[:resource].read_string
        r ? (hash[n.to_sym] ||= {} and hash[n.to_sym][r.to_sym] = v) : hash[n.to_sym] = v
        attrl = attrl[:next]
      end
      hash
    end
  end

  # Struct for Attribute Operation C-linked list
  class Attropl < ::FFI::Struct
    layout :next,     Attropl.ptr,      # pointer to next Attropl object
           :name,     :pointer,         # string for name of attribute
           :resource, :pointer,         # string for resource if this attribute is a resource
           :value,    :pointer,         # string for value of attribute
           :op,       BatchOp           # operation to perform for this attribute

    # Convert to C-linked list of structs from list of hashes
    # @param list [Array<#to_h>] list of hashes describing attribute
    # @return [Attropl] generated attribute operation c-linked list object
    def self.from_list(list)
      list = list.map(&:to_h)
      attropl = nil
      prev = Attropl.new(::FFI::Pointer::NULL)
      list.each do |attrib|
        attropl = Attropl.new
        attropl[:name]     = ::FFI::MemoryPointer.from_string attrib[:name].to_s
        attropl[:value]    = ::FFI::MemoryPointer.from_string attrib[:value].to_s
        attropl[:resource] = ::FFI::MemoryPointer.from_string attrib[:resource].to_s
        attropl[:op]       = (attrib[:op] || :eq).to_sym
        attropl[:next]     = prev
        prev = attropl
      end
      attropl
    end
  end

  # Struct for PBS batch server status responses
  class BatchStatus < ::FFI::ManagedStruct
    layout :next,     BatchStatus.ptr,  # pointer to next BatchStatus object
           :name,     :string,          # string for name of this status
           :attribs,  Attrl.ptr,        # pointer to beginning of C-linked list of an Attrl object
           :text,     :string           # string containing unknown text

    # Free memory for allocated {BatchStatus} C-linked list
    def self.release(ptr)
      pbs_statfree(ptr)
    end

    # Convert to hash describing this linked list
    # @return [Hash] hash describing linked list
    def to_h
      batch = self
      hash = {}
      until batch.to_ptr.null?
        hash[batch[:name]] = batch[:attribs].to_h
        batch = batch[:next]
      end
      hash
    end
  end

  # Defined error codes, valid as of Torque >=4.2.10
  ERROR_CODES = {
    15001 =>   UnkjobidError,
    15002 =>   NoattrError,
    15003 =>   AttrroError,
    15004 =>   IvalreqError,
    15005 =>   UnkreqError,
    15006 =>   ToomanyError,
    15007 =>   PermError,
    15008 =>   IffNotFoundError,
    15009 =>   MungeNotFoundError,
    15010 =>   BadhostError,
    15011 =>   JobexistError,
    15012 =>   SystemError,
    15013 =>   InternalError,
    15014 =>   RegrouteError,
    15015 =>   UnksigError,
    15016 =>   BadatvalError,
    15017 =>   ModatrrunError,
    15018 =>   BadstateError,
    15020 =>   UnkqueError,
    15021 =>   BadcredError,
    15022 =>   ExpiredError,
    15023 =>   QunoenbError,
    15024 =>   QacessError,
    15025 =>   BaduserError,
    15026 =>   HopcountError,
    15027 =>   QueexistError,
    15028 =>   AttrtypeError,
    15029 =>   QuebusyError,
    15030 =>   QuenbigError,
    15031 =>   NosupError,
    15032 =>   QuenoenError,
    15033 =>   ProtocolError,
    15034 =>   BadatlstError,
    15035 =>   NoconnectsError,
    15036 =>   NoserverError,
    15037 =>   UnkrescError,
    15038 =>   ExcqrescError,
    15039 =>   QuenodfltError,
    15040 =>   NorerunError,
    15041 =>   RouterejError,
    15042 =>   RouteexpdError,
    15043 =>   MomrejectError,
    15044 =>   BadscriptError,
    15045 =>   StageinError,
    15046 =>   RescunavError,
    15047 =>   BadgrpError,
    15048 =>   MaxquedError,
    15049 =>   CkpbsyError,
    15050 =>   ExlimitError,
    15051 =>   BadacctError,
    15052 =>   AlrdyexitError,
    15053 =>   NocopyfileError,
    15054 =>   CleanedoutError,
    15055 =>   NosyncmstrError,
    15056 =>   BaddependError,
    15057 =>   DuplistError,
    15058 =>   DisprotoError,
    15059 =>   ExecthereError,
    15060 =>   SisrejectError,
    15061 =>   SiscommError,
    15062 =>   SvrdownError,
    15063 =>   CkpshortError,
    15064 =>   UnknodeError,
    15065 =>   UnknodeatrError,
    15066 =>   NonodesError,
    15067 =>   NodenbigError,
    15068 =>   NodeexistError,
    15069 =>   BadndatvalError,
    15070 =>   MutualexError,
    15071 =>   GmoderrError,
    15072 =>   NorelymomError,
    15073 =>   NotsnodeError,
    15074 =>   JobtypeError,
    15075 =>   BadaclhostError,
    15076 =>   MaxuserquedError,
    15077 =>   BaddisallowtypeError,
    15078 =>   NointeractiveError,
    15079 =>   NobatchError,
    15080 =>   NorerunableError,
    15081 =>   NononrerunableError,
    15082 =>   UnkarrayidError,
    15083 =>   BadArrayReqError,
    15084 =>   BadArrayDataError,
    15085 =>   TimeoutError,
    15086 =>   JobnotfoundError,
    15087 =>   NofaulttolerantError,
    15088 =>   NofaultintolerantError,
    15089 =>   NojobarraysError,
    15090 =>   RelayedToMomError,
    15091 =>   MemMallocError,
    15092 =>   MutexError,
    15093 =>   ThreadattrError,
    15094 =>   ThreadError,
    15095 =>   SelectError,
    15096 =>   SocketFaultError,
    15097 =>   SocketWriteError,
    15098 =>   SocketReadError,
    15099 =>   SocketCloseError,
    15100 =>   SocketListenError,
    15101 =>   AuthInvalidError,
    15102 =>   NotImplementedError,
    15103 =>   QuenotavailableError,
    15104 =>   TmpdiffownerError,
    15105 =>   TmpnotdirError,
    15106 =>   TmpnonameError,
    15107 =>   CantopensocketError,
    15108 =>   CantcontactsistersError,
    15109 =>   CantcreatetmpdirError,
    15110 =>   BadmomstateError,
    15111 =>   SocketInformationError,
    15112 =>   SocketDataError,
    15113 =>   ClientInvalidError,
    15114 =>   PrematureEofError,
    15115 =>   CanNotSaveFileError,
    15116 =>   CanNotOpenFileError,
    15117 =>   CanNotWriteFileError,
    15118 =>   JobFileCorruptError,
    15119 =>   JobRerunError,
    15120 =>   ConnectError,
    15121 =>   JobworkdelayError,
    15122 =>   BadParameterError,
    15123 =>   ContinueError,
    15124 =>   JobsubstateError,
    15125 =>   CanNotMoveFileError,
    15126 =>   JobRecycledError,
    15127 =>   JobAlreadyInQueueError,
    15128 =>   InvalidMutexError,
    15129 =>   MutexAlreadyLockedError,
    15130 =>   MutexAlreadyUnlockedError,
    15131 =>   InvalidSyntaxError,
    15132 =>   NodeDownError,
    15133 =>   ServerNotFoundError,
    15134 =>   ServerBusyError,
  }
end
