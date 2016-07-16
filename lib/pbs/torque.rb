require "ffi"

module PBS
  module Torque
    extend FFI::Library

    def self.lib
      @lib
    end

    # Define torque methods using a supplied library
    def self.lib=(lib)
      @lib = lib ? lib.to_s : 'torque'

      # Set up FFI to use this library
      ffi_lib @lib

      # int pbs_errno
      attach_variable :pbs_errno, :int

      # char *pbs_server
      attach_variable :pbs_server, :string

      # int pbs_connect(char *server)
      attach_function :pbs_connect, [ :pointer ], :int

      # char *pbs_default(void)
      attach_function :pbs_default, [], :string

      # char *pbs_strerror(int errno)
      attach_function :pbs_strerror, [ :int ], :string

      # int pbs_deljob(int connect, char *job_id, char *extend)
      attach_function :pbs_deljob, [ :int, :pointer, :pointer ], :int

      # int pbs_disconnect(int connect)
      attach_function :pbs_disconnect, [ :int ], :int

      # int pbs_holdjob(int connect, char *job_id, char *hold_type, char *extend)
      attach_function :pbs_holdjob, [ :int, :pointer, :pointer, :pointer ], :int

      # int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend)
      attach_function :pbs_rlsjob, [ :int, :pointer, :pointer, :pointer ], :int

      # void pbs_statfree(struct batch_status *stat)
      attach_function :pbs_statfree, [ :pointer ], :void

      # batch_status * pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend)
      attach_function :pbs_statjob, [ :int, :pointer, :pointer, :pointer ], BatchStatus.ptr

      # batch_status * pbs_statnode(int connect, char *id, struct attrl *attrib, char *extend)
      attach_function :pbs_statnode, [ :int, :pointer, :pointer, :pointer ], BatchStatus.ptr

      # batch_status * pbs_statque(int connect, char *id, struct attrl *attrib, char *extend)
      attach_function :pbs_statque, [ :int, :pointer, :pointer, :pointer ], BatchStatus.ptr

      # batch_status * pbs_statserver(int connect, struct attrl *attrib, char *extend)
      attach_function :pbs_statserver, [ :int, :pointer, :pointer ], BatchStatus.ptr

      # char *pbs_submit(int connect, struct attropl *attrib, char *script, char *destination, char *extend)
      attach_function :pbs_submit, [ :int, :pointer, :pointer, :pointer, :pointer ], :string
    end

    def self.check_for_error
      errno = pbs_errno
      self.pbs_errno = 0  # reset error number
      raise_error(errno) if errno > 0
    end

    def self.raise_error(errno)
      raise (ERROR_CODES[errno] || PBS::Error), "#{pbs_strerror(errno)}"
    end

    # Data structures defined in pbs_ifl.h

    # Enum for Batch Operation
    BatchOp = enum(:set, :unset, :incr, :decr, :eq, :ne, :ge, :gt, :le, :lt, :dflt, :merge, :incr_old)

    # Struct for Attribute C-linked list
    class Attrl < FFI::Struct
      layout :next,     Attrl.ptr,        # pointer to next Attrl object
             :name,     :pointer,         # string for name of attribute
             :resource, :pointer,         # string for resource if this attribute is a resource
             :value,    :pointer,         # string for value of attribute
             :op,       BatchOp           # not used in an Attrl object

      def self.from_list(list)
        attrl = nil
        prev = Attrl.new(FFI::Pointer::NULL)
        list.each do |key|
          attrl = Attrl.new
          attrl[:name] = FFI::MemoryPointer.from_string(key.to_s)
          attrl[:resource] = FFI::Pointer::NULL
          attrl[:value] = FFI::Pointer::NULL
          attrl[:op] = 0
          attrl[:next] = prev
          prev = attrl
        end
        attrl
      end

      def to_hash
        hash = Hash.new{ |h,k| h[k] = Hash.new() }
        attrl = self
        until attrl.to_ptr.null?
          name = attrl[:name].read_string.to_sym
          value = attrl[:value].read_string
          resource = nil
          resource = attrl[:resource].read_string.to_sym unless attrl[:resource].null?
          if resource.nil?
            hash[name] = value
          else
            hash[name][resource] = value
          end
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

      def self.from_hash(hash)
        # Convert hash into array
        # Format: {name: value, name: {resource: value, resource: value}}
        # {a: 1, b: {c: 2, d: 3}} => [[:a,1],[:b,2,:c],[:b,3,:d]]
        ary = hash.map{|k,v| [*v].map{|v2| [k,*[*v2].reverse]}}.flatten(1)
        attropl = nil
        prev = Attropl.new(FFI::Pointer::NULL)
        ary.each do |attrib|
          attropl = Attropl.new
          attropl[:name] = FFI::MemoryPointer.from_string(attrib[0].to_s)
          attropl[:value] = FFI::MemoryPointer.from_string(attrib[1])
          attropl[:resource] = FFI::MemoryPointer.from_string(attrib[2].to_s) unless attrib[2].nil?
          attropl[:op] = 0
          attropl[:next] = prev
          prev = attropl
        end
        attropl
      end
    end

    # Struct for status of batch
    class BatchStatus < FFI::ManagedStruct
      layout :next,     BatchStatus.ptr,  # pointer to next BatchStatus object
             :name,     :string,          # string for name of this status
             :attribs,  Attrl.ptr,        # pointer to beginning of C-linked list of an Attrl object
             :text,     :string           # string containing unknown text

      def self.release(ptr)
        pbs_statfree(ptr)
      end

      def to_a
        ary = []
        batch = self
        until batch.to_ptr.null?
          ary << {name: batch[:name], attribs: batch[:attribs].to_hash}
          batch = batch[:next]
        end
        ary
      end
    end

    # Defined error codes
    # valid as of Torque >=4.2.10
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
