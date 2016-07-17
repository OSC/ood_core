require 'ffi'

module PBS
  # An interface to the C-library of Torque
  module Torque
    extend FFI::Library

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

      # @!attribute [rw] pbs_errno
      #   The internal PBS error number
      #     int pbs_errno
      #   @return [Fixnum] pbs error number
      attach_variable :pbs_errno, :int

      # @!attribute [r] pbs_server
      #   The PBS server name
      #     char *pbs_server
      #   @return [String] pbs server name
      attach_variable :pbs_server, :string

      # @!method pbs_strerror(errno)
      #   Generates PBS error string from given error number
      #     char *pbs_strerror(int errno)
      #   @param errno [Fixnum] pbs error number
      #   @return [String] pbs error string
      attach_function :pbs_strerror, [ :int ], :string

      # @!method pbs_default
      #   Default PBS server name
      #     char *pbs_default(void)
      #   @see http://linux.die.net/man/3/pbs_default
      #   @return [String] default pbs server name
      attach_function :pbs_default, [], :string

      # @!method pbs_connect(server)
      #   Connect to PBS batch server
      #     int pbs_connect(char *server)
      #   @see http://linux.die.net/man/3/pbs_connect
      #   @param server [String] name of pbs server
      #   @return [Fixnum] connection identifier
      attach_function :pbs_connect, [ :string ], :int

      # @!method pbs_disconnect(connect)
      #   Disconnect from a PBS batch server
      #     int pbs_disconnect(int connect)
      #   @see http://linux.die.net/man/3/pbs_disconnect
      #   @param connect [Fixnum] connection identifier
      #   @return [Fixnum] exit status code
      attach_function :pbs_disconnect, [ :int ], :int

      # @!method pbs_deljob(connect, job_id, extend)
      #   Delete a PBS batch job
      #     int pbs_deljob(int connect, char *job_id, char *extend)
      #   @see http://linux.die.net/man/3/pbs_deljob
      #   @param connect [Fixnum] connection identifier
      #   @param job_id [String] the job id
      #   @param extend [String] implementation defined extensions
      #   @return [Fixnum] exit status code
      attach_function :pbs_deljob, [ :int, :string, :string ], :int

      # @!method pbs_holdjob(connect, job_id, hold_type, extend)
      #   Place a hold on a PBS batch job
      #     int pbs_holdjob(int connect, char *job_id, char *hold_type, char *extend)
      #   @see http://linux.die.net/man/3/pbs_holdjob
      #   @param connect [Fixnum] connection identifier
      #   @param job_id [String] the job id
      #   @param hold_type [String] type of hold to be applied
      #   @param extend [String] implementation defined extensions
      #   @return [Fixnum] exit status code
      attach_function :pbs_holdjob, [ :int, :string, :string, :string ], :int

      # @!method pbs_rlsjob(connect, job_id, hold_type, extend)
      #   Release a hold on a PBS batch job
      #     int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend)
      #   @see http://linux.die.net/man/3/pbs_rlsjob
      #   @param connect [Fixnum] connection identifier
      #   @param job_id [String] the job id
      #   @param hold_type [String] type of hold to be released
      #   @param extend [String] implementation defined extensions
      #   @return [Fixnum] exit status code
      attach_function :pbs_rlsjob, [ :int, :string, :string, :string ], :int

      # @!method pbs_statfree(stat)
      #   Free the memory allocated by {BatchStatus} object
      #     void pbs_statfree(struct batch_status *stat)
      #   @param stat [BatchStatus] the batch status object
      #   @return [void]
      attach_function :pbs_statfree, [ BatchStatus.ptr ], :void

      # @!method pbs_statjob(connect, id, attrib, extend)
      #   Obtain status of PBS batch jobs
      #     batch_status * pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend)
      #   @see http://linux.die.net/man/3/pbs_statjob
      #   @param connect [Fixnum] connection identifier
      #   @param id [String] job or destination identifier
      #   @param attrib [Attrl] the attribute c-linked list object
      #   @param extend [String] implementation defined extensions
      #   @return [BatchStatus] c-linked list of batch status objects
      #   @note It is up to the user to free the space of the batch status objects
      attach_function :pbs_statjob, [ :int, :string, Attrl.ptr, :string ], BatchStatus.ptr

      # @!method pbs_statnode(connect, id, attrib, extend)
      #   Obtain status of PBS nodes
      #     batch_status * pbs_statnode(int connect, char *id, struct attrl *attrib, char *extend)
      #   @see http://linux.die.net/man/3/pbs_statnode
      #   @param connect [Fixnum] connection identifier
      #   @param id [String] name of a node or null string
      #   @param attrib [Attrl] the attribute c-linked list object
      #   @param extend [String] implementation defined extensions
      #   @return [BatchStatus] c-linked list of batch status objects
      #   @note It is up to the user to free the space of the batch status objects
      attach_function :pbs_statnode, [ :int, :string, Attrl.ptr, :string ], BatchStatus.ptr

      # @!method pbs_statque(connect, id, attrib, extend)
      #   Obtain status of PBS batch queues
      #     batch_status * pbs_statque(int connect, char *id, struct attrl *attrib, char *extend)
      #   @see http://linux.die.net/man/3/pbs_statque
      #   @param connect [Fixnum] connection identifier
      #   @param id [String] name of a queue or null string
      #   @param attrib [Attrl] the attribute c-linked list object
      #   @param extend [String] implementation defined extensions
      #   @return [BatchStatus] c-linked list of batch status objects
      #   @note It is up to the user to free the space of the batch status objects
      attach_function :pbs_statque, [ :int, :string, Attrl.ptr, :string ], BatchStatus.ptr

      # @!method pbs_statserver(connect, attrib, extend)
      #   Obtain status of a PBS batch server
      #     batch_status * pbs_statserver(int connect, struct attrl *attrib, char *extend)
      #   @see http://linux.die.net/man/3/pbs_statserver
      #   @param connect [Fixnum] connection identifier
      #   @param attrib [Attrl] the attribute c-linked list object
      #   @param extend [String] implementation defined extensions
      #   @return [BatchStatus] c-linked list of batch status objects
      #   @note It is up to the user to free the space of the batch status objects
      attach_function :pbs_statserver, [ :int, Attrl.ptr, :string ], BatchStatus.ptr

      # FIXME: The space for the job_identifier string is allocated by
      # pbs_submit() and should be released via a call to free() when no longer
      # needed
      # @!method pbs_submit(connect, attrib, script, destination, extend)
      #   Submit a PBS batch job
      #     char *pbs_submit(int connect, struct attropl *attrib, char *script, char *destination, char *extend)
      #   @see http://linux.die.net/man/3/pbs_submit
      #   @param connect [Fixnum] connection identifier
      #   @param attrib [Attropl] the attribute operation c-linked list object
      #   @param script [String] the path to the script
      #   @param destination [String] the queue to send job to
      #   @param extend [String] implementation defined extensions
      #   @return [String] the job id
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
    class Attrl < FFI::Struct
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
        prev = Attrl.new(FFI::Pointer::NULL)
        list.each do |key|
          attrl = Attrl.new
          attrl[:name] = FFI::MemoryPointer.from_string(key.to_s)
          attrl[:next] = prev
          prev = attrl
        end
        attrl
      end

      # Convert to hash describing this linked list
      # @return [Hash] hash describing linked list
      def to_h
        attrl = self
        hash = Hash.new{ |h,k| h[k] = Hash.new() }
        until attrl.to_ptr.null?
          n = attrl[:name].read_string
          v = attrl[:value].read_string
          r = attrl[:resource].null? ? nil : attrl[:resource].read_string
          r ? hash[n.to_sym][r.to_sym] = v : hash[n.to_sym] = v
          attrl = attrl[:next]
        end
        hash
      end
    end

    # Struct for Attribute Operation C-linked list
    class Attropl < FFI::Struct
      layout :next,     Attropl.ptr,      # pointer to next Attropl object
             :name,     :pointer,         # string for name of attribute
             :resource, :pointer,         # string for resource if this attribute is a resource
             :value,    :pointer,         # string for value of attribute
             :op,       BatchOp           # operation to perform for this attribute

      # Convert to C-linked list of structs from hash
      # @param hash [Hash] hash representation of this c-linked list
      # @return [Attropl] generated attribute operation c-linked list object
      def self.from_hash(hash)
        # Convert hash into array
        # Format: {name: value, name: {resource: value, resource: value}}
        # {a: 1, b: {c: 2, d: 3}} => [[:a,1],[:b,2,:c],[:b,3,:d]]
        ary = hash.map{|k,v| [*v].map{|v2| [k,*[*v2].reverse]}}.flatten(1)
        attropl = nil
        prev = Attropl.new(FFI::Pointer::NULL)
        ary.each do |attrib|
          attropl = Attropl.new
          attropl[:name]     = FFI::MemoryPointer.from_string attrib[0].to_s
          attropl[:value]    = FFI::MemoryPointer.from_string attrib[1].to_s
          attropl[:resource] = FFI::MemoryPointer.from_string attrib[2].to_s if attrib[2]
          attropl[:next]     = prev
          prev = attropl
        end
        attropl
      end
    end

    # Struct for PBS batch server status responses
    class BatchStatus < FFI::ManagedStruct
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
      15001 => PBS::UnkjobidError,
      15002 => PBS::NoattrError,
      15003 => PBS::AttrroError,
      15004 => PBS::IvalreqError,
      15005 => PBS::UnkreqError,
      15006 => PBS::ToomanyError,
      15007 => PBS::PermError,
      15008 => PBS::IffNotFoundError,
      15009 => PBS::MungeNotFoundError,
      15010 => PBS::BadhostError,
      15011 => PBS::JobexistError,
      15012 => PBS::SystemError,
      15013 => PBS::InternalError,
      15014 => PBS::RegrouteError,
      15015 => PBS::UnksigError,
      15016 => PBS::BadatvalError,
      15017 => PBS::ModatrrunError,
      15018 => PBS::BadstateError,
      15020 => PBS::UnkqueError,
      15021 => PBS::BadcredError,
      15022 => PBS::ExpiredError,
      15023 => PBS::QunoenbError,
      15024 => PBS::QacessError,
      15025 => PBS::BaduserError,
      15026 => PBS::HopcountError,
      15027 => PBS::QueexistError,
      15028 => PBS::AttrtypeError,
      15029 => PBS::QuebusyError,
      15030 => PBS::QuenbigError,
      15031 => PBS::NosupError,
      15032 => PBS::QuenoenError,
      15033 => PBS::ProtocolError,
      15034 => PBS::BadatlstError,
      15035 => PBS::NoconnectsError,
      15036 => PBS::NoserverError,
      15037 => PBS::UnkrescError,
      15038 => PBS::ExcqrescError,
      15039 => PBS::QuenodfltError,
      15040 => PBS::NorerunError,
      15041 => PBS::RouterejError,
      15042 => PBS::RouteexpdError,
      15043 => PBS::MomrejectError,
      15044 => PBS::BadscriptError,
      15045 => PBS::StageinError,
      15046 => PBS::RescunavError,
      15047 => PBS::BadgrpError,
      15048 => PBS::MaxquedError,
      15049 => PBS::CkpbsyError,
      15050 => PBS::ExlimitError,
      15051 => PBS::BadacctError,
      15052 => PBS::AlrdyexitError,
      15053 => PBS::NocopyfileError,
      15054 => PBS::CleanedoutError,
      15055 => PBS::NosyncmstrError,
      15056 => PBS::BaddependError,
      15057 => PBS::DuplistError,
      15058 => PBS::DisprotoError,
      15059 => PBS::ExecthereError,
      15060 => PBS::SisrejectError,
      15061 => PBS::SiscommError,
      15062 => PBS::SvrdownError,
      15063 => PBS::CkpshortError,
      15064 => PBS::UnknodeError,
      15065 => PBS::UnknodeatrError,
      15066 => PBS::NonodesError,
      15067 => PBS::NodenbigError,
      15068 => PBS::NodeexistError,
      15069 => PBS::BadndatvalError,
      15070 => PBS::MutualexError,
      15071 => PBS::GmoderrError,
      15072 => PBS::NorelymomError,
      15073 => PBS::NotsnodeError,
      15074 => PBS::JobtypeError,
      15075 => PBS::BadaclhostError,
      15076 => PBS::MaxuserquedError,
      15077 => PBS::BaddisallowtypeError,
      15078 => PBS::NointeractiveError,
      15079 => PBS::NobatchError,
      15080 => PBS::NorerunableError,
      15081 => PBS::NononrerunableError,
      15082 => PBS::UnkarrayidError,
      15083 => PBS::BadArrayReqError,
      15084 => PBS::BadArrayDataError,
      15085 => PBS::TimeoutError,
      15086 => PBS::JobnotfoundError,
      15087 => PBS::NofaulttolerantError,
      15088 => PBS::NofaultintolerantError,
      15089 => PBS::NojobarraysError,
      15090 => PBS::RelayedToMomError,
      15091 => PBS::MemMallocError,
      15092 => PBS::MutexError,
      15093 => PBS::ThreadattrError,
      15094 => PBS::ThreadError,
      15095 => PBS::SelectError,
      15096 => PBS::SocketFaultError,
      15097 => PBS::SocketWriteError,
      15098 => PBS::SocketReadError,
      15099 => PBS::SocketCloseError,
      15100 => PBS::SocketListenError,
      15101 => PBS::AuthInvalidError,
      15102 => PBS::NotImplementedError,
      15103 => PBS::QuenotavailableError,
      15104 => PBS::TmpdiffownerError,
      15105 => PBS::TmpnotdirError,
      15106 => PBS::TmpnonameError,
      15107 => PBS::CantopensocketError,
      15108 => PBS::CantcontactsistersError,
      15109 => PBS::CantcreatetmpdirError,
      15110 => PBS::BadmomstateError,
      15111 => PBS::SocketInformationError,
      15112 => PBS::SocketDataError,
      15113 => PBS::ClientInvalidError,
      15114 => PBS::PrematureEofError,
      15115 => PBS::CanNotSaveFileError,
      15116 => PBS::CanNotOpenFileError,
      15117 => PBS::CanNotWriteFileError,
      15118 => PBS::JobFileCorruptError,
      15119 => PBS::JobRerunError,
      15120 => PBS::ConnectError,
      15121 => PBS::JobworkdelayError,
      15122 => PBS::BadParameterError,
      15123 => PBS::ContinueError,
      15124 => PBS::JobsubstateError,
      15125 => PBS::CanNotMoveFileError,
      15126 => PBS::JobRecycledError,
      15127 => PBS::JobAlreadyInQueueError,
      15128 => PBS::InvalidMutexError,
      15129 => PBS::MutexAlreadyLockedError,
      15130 => PBS::MutexAlreadyUnlockedError,
      15131 => PBS::InvalidSyntaxError,
      15132 => PBS::NodeDownError,
      15133 => PBS::ServerNotFoundError,
      15134 => PBS::ServerBusyError,
    }
  end
end
