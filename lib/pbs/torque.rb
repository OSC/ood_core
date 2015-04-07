require "ffi"

module PBS
  module Torque
    extend FFI::Library

    # Define torque methods using a supplied library
    def self.init(args = {})
      @@lib = args[:lib] || "torque"

      # Set up FFI to use this library
      ffi_lib @@lib

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
      raise PBS::Error, "#{pbs_strerror(errno)}" if errno > 0
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
  end
end
