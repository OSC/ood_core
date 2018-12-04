require 'ffi'

class OodCore::Job::Adapters::Torque::FFI
  # An interface to the C-library of Torque
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
      15001 =>   OodCore::Job::Adapters::Torque::UnkjobidError,
      15002 =>   OodCore::Job::Adapters::Torque::NoattrError,
      15003 =>   OodCore::Job::Adapters::Torque::AttrroError,
      15004 =>   OodCore::Job::Adapters::Torque::IvalreqError,
      15005 =>   OodCore::Job::Adapters::Torque::UnkreqError,
      15006 =>   OodCore::Job::Adapters::Torque::ToomanyError,
      15007 =>   OodCore::Job::Adapters::Torque::PermError,
      15008 =>   OodCore::Job::Adapters::Torque::IffNotFoundError,
      15009 =>   OodCore::Job::Adapters::Torque::MungeNotFoundError,
      15010 =>   OodCore::Job::Adapters::Torque::BadhostError,
      15011 =>   OodCore::Job::Adapters::Torque::JobexistError,
      15012 =>   OodCore::Job::Adapters::Torque::SystemError,
      15013 =>   OodCore::Job::Adapters::Torque::InternalError,
      15014 =>   OodCore::Job::Adapters::Torque::RegrouteError,
      15015 =>   OodCore::Job::Adapters::Torque::UnksigError,
      15016 =>   OodCore::Job::Adapters::Torque::BadatvalError,
      15017 =>   OodCore::Job::Adapters::Torque::ModatrrunError,
      15018 =>   OodCore::Job::Adapters::Torque::BadstateError,
      15020 =>   OodCore::Job::Adapters::Torque::UnkqueError,
      15021 =>   OodCore::Job::Adapters::Torque::BadcredError,
      15022 =>   OodCore::Job::Adapters::Torque::ExpiredError,
      15023 =>   OodCore::Job::Adapters::Torque::QunoenbError,
      15024 =>   OodCore::Job::Adapters::Torque::QacessError,
      15025 =>   OodCore::Job::Adapters::Torque::BaduserError,
      15026 =>   OodCore::Job::Adapters::Torque::HopcountError,
      15027 =>   OodCore::Job::Adapters::Torque::QueexistError,
      15028 =>   OodCore::Job::Adapters::Torque::AttrtypeError,
      15029 =>   OodCore::Job::Adapters::Torque::QuebusyError,
      15030 =>   OodCore::Job::Adapters::Torque::QuenbigError,
      15031 =>   OodCore::Job::Adapters::Torque::NosupError,
      15032 =>   OodCore::Job::Adapters::Torque::QuenoenError,
      15033 =>   OodCore::Job::Adapters::Torque::ProtocolError,
      15034 =>   OodCore::Job::Adapters::Torque::BadatlstError,
      15035 =>   OodCore::Job::Adapters::Torque::NoconnectsError,
      15036 =>   OodCore::Job::Adapters::Torque::NoserverError,
      15037 =>   OodCore::Job::Adapters::Torque::UnkrescError,
      15038 =>   OodCore::Job::Adapters::Torque::ExcqrescError,
      15039 =>   OodCore::Job::Adapters::Torque::QuenodfltError,
      15040 =>   OodCore::Job::Adapters::Torque::NorerunError,
      15041 =>   OodCore::Job::Adapters::Torque::RouterejError,
      15042 =>   OodCore::Job::Adapters::Torque::RouteexpdError,
      15043 =>   OodCore::Job::Adapters::Torque::MomrejectError,
      15044 =>   OodCore::Job::Adapters::Torque::BadscriptError,
      15045 =>   OodCore::Job::Adapters::Torque::StageinError,
      15046 =>   OodCore::Job::Adapters::Torque::RescunavError,
      15047 =>   OodCore::Job::Adapters::Torque::BadgrpError,
      15048 =>   OodCore::Job::Adapters::Torque::MaxquedError,
      15049 =>   OodCore::Job::Adapters::Torque::CkpbsyError,
      15050 =>   OodCore::Job::Adapters::Torque::ExlimitError,
      15051 =>   OodCore::Job::Adapters::Torque::BadacctError,
      15052 =>   OodCore::Job::Adapters::Torque::AlrdyexitError,
      15053 =>   OodCore::Job::Adapters::Torque::NocopyfileError,
      15054 =>   OodCore::Job::Adapters::Torque::CleanedoutError,
      15055 =>   OodCore::Job::Adapters::Torque::NosyncmstrError,
      15056 =>   OodCore::Job::Adapters::Torque::BaddependError,
      15057 =>   OodCore::Job::Adapters::Torque::DuplistError,
      15058 =>   OodCore::Job::Adapters::Torque::DisprotoError,
      15059 =>   OodCore::Job::Adapters::Torque::ExecthereError,
      15060 =>   OodCore::Job::Adapters::Torque::SisrejectError,
      15061 =>   OodCore::Job::Adapters::Torque::SiscommError,
      15062 =>   OodCore::Job::Adapters::Torque::SvrdownError,
      15063 =>   OodCore::Job::Adapters::Torque::CkpshortError,
      15064 =>   OodCore::Job::Adapters::Torque::UnknodeError,
      15065 =>   OodCore::Job::Adapters::Torque::UnknodeatrError,
      15066 =>   OodCore::Job::Adapters::Torque::NonodesError,
      15067 =>   OodCore::Job::Adapters::Torque::NodenbigError,
      15068 =>   OodCore::Job::Adapters::Torque::NodeexistError,
      15069 =>   OodCore::Job::Adapters::Torque::BadndatvalError,
      15070 =>   OodCore::Job::Adapters::Torque::MutualexError,
      15071 =>   OodCore::Job::Adapters::Torque::GmoderrError,
      15072 =>   OodCore::Job::Adapters::Torque::NorelymomError,
      15073 =>   OodCore::Job::Adapters::Torque::NotsnodeError,
      15074 =>   OodCore::Job::Adapters::Torque::JobtypeError,
      15075 =>   OodCore::Job::Adapters::Torque::BadaclhostError,
      15076 =>   OodCore::Job::Adapters::Torque::MaxuserquedError,
      15077 =>   OodCore::Job::Adapters::Torque::BaddisallowtypeError,
      15078 =>   OodCore::Job::Adapters::Torque::NointeractiveError,
      15079 =>   OodCore::Job::Adapters::Torque::NobatchError,
      15080 =>   OodCore::Job::Adapters::Torque::NorerunableError,
      15081 =>   OodCore::Job::Adapters::Torque::NononrerunableError,
      15082 =>   OodCore::Job::Adapters::Torque::UnkarrayidError,
      15083 =>   OodCore::Job::Adapters::Torque::BadArrayReqError,
      15084 =>   OodCore::Job::Adapters::Torque::BadArrayDataError,
      15085 =>   OodCore::Job::Adapters::Torque::TimeoutError,
      15086 =>   OodCore::Job::Adapters::Torque::JobnotfoundError,
      15087 =>   OodCore::Job::Adapters::Torque::NofaulttolerantError,
      15088 =>   OodCore::Job::Adapters::Torque::NofaultintolerantError,
      15089 =>   OodCore::Job::Adapters::Torque::NojobarraysError,
      15090 =>   OodCore::Job::Adapters::Torque::RelayedToMomError,
      15091 =>   OodCore::Job::Adapters::Torque::MemMallocError,
      15092 =>   OodCore::Job::Adapters::Torque::MutexError,
      15093 =>   OodCore::Job::Adapters::Torque::ThreadattrError,
      15094 =>   OodCore::Job::Adapters::Torque::ThreadError,
      15095 =>   OodCore::Job::Adapters::Torque::SelectError,
      15096 =>   OodCore::Job::Adapters::Torque::SocketFaultError,
      15097 =>   OodCore::Job::Adapters::Torque::SocketWriteError,
      15098 =>   OodCore::Job::Adapters::Torque::SocketReadError,
      15099 =>   OodCore::Job::Adapters::Torque::SocketCloseError,
      15100 =>   OodCore::Job::Adapters::Torque::SocketListenError,
      15101 =>   OodCore::Job::Adapters::Torque::AuthInvalidError,
      15102 =>   OodCore::Job::Adapters::Torque::NotImplementedError,
      15103 =>   OodCore::Job::Adapters::Torque::QuenotavailableError,
      15104 =>   OodCore::Job::Adapters::Torque::TmpdiffownerError,
      15105 =>   OodCore::Job::Adapters::Torque::TmpnotdirError,
      15106 =>   OodCore::Job::Adapters::Torque::TmpnonameError,
      15107 =>   OodCore::Job::Adapters::Torque::CantopensocketError,
      15108 =>   OodCore::Job::Adapters::Torque::CantcontactsistersError,
      15109 =>   OodCore::Job::Adapters::Torque::CantcreatetmpdirError,
      15110 =>   OodCore::Job::Adapters::Torque::BadmomstateError,
      15111 =>   OodCore::Job::Adapters::Torque::SocketInformationError,
      15112 =>   OodCore::Job::Adapters::Torque::SocketDataError,
      15113 =>   OodCore::Job::Adapters::Torque::ClientInvalidError,
      15114 =>   OodCore::Job::Adapters::Torque::PrematureEofError,
      15115 =>   OodCore::Job::Adapters::Torque::CanNotSaveFileError,
      15116 =>   OodCore::Job::Adapters::Torque::CanNotOpenFileError,
      15117 =>   OodCore::Job::Adapters::Torque::CanNotWriteFileError,
      15118 =>   OodCore::Job::Adapters::Torque::JobFileCorruptError,
      15119 =>   OodCore::Job::Adapters::Torque::JobRerunError,
      15120 =>   OodCore::Job::Adapters::Torque::ConnectError,
      15121 =>   OodCore::Job::Adapters::Torque::JobworkdelayError,
      15122 =>   OodCore::Job::Adapters::Torque::BadParameterError,
      15123 =>   OodCore::Job::Adapters::Torque::ContinueError,
      15124 =>   OodCore::Job::Adapters::Torque::JobsubstateError,
      15125 =>   OodCore::Job::Adapters::Torque::CanNotMoveFileError,
      15126 =>   OodCore::Job::Adapters::Torque::JobRecycledError,
      15127 =>   OodCore::Job::Adapters::Torque::JobAlreadyInQueueError,
      15128 =>   OodCore::Job::Adapters::Torque::InvalidMutexError,
      15129 =>   OodCore::Job::Adapters::Torque::MutexAlreadyLockedError,
      15130 =>   OodCore::Job::Adapters::Torque::MutexAlreadyUnlockedError,
      15131 =>   OodCore::Job::Adapters::Torque::InvalidSyntaxError,
      15132 =>   OodCore::Job::Adapters::Torque::NodeDownError,
      15133 =>   OodCore::Job::Adapters::Torque::ServerNotFoundError,
      15134 =>   OodCore::Job::Adapters::Torque::ServerBusyError,
    }
end
