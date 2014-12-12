#
# Copyright (C) 2014 Jeremy Nicklas
#
# This file is part of pbs-ruby.
#
# All rights reserved.
#

require 'ffi'

module PBS

  # Torque library can be changed dynamically
  @@torque_lib = 'torque'

  def self.set(lib)
    @@torque_lib = lib
    ffi_lib @@torque_lib
  end

  def self.get
    @@torque_lib
  end

  # FFI Library extension using above torque lib
  extend FFI::Library
  ffi_lib @@torque_lib


  # Module methods below
  #################################################
  extend self

  # int pbs_errno /* error number */
  attach_variable :_pbs_errno, :pbs_errno, :int

  # int pbs_connect(char *server)
  attach_function :_pbs_connect, :pbs_connect, [ :pointer ], :int

  # char *pbs_default(void);
  attach_function :_pbs_default, :pbs_default, [], :string
  
  # int pbs_deljob(int connect, char *job_id, char *extend)
  attach_function :_pbs_deljob, :pbs_deljob, [ :int, :pointer, :pointer ], :int

  # int pbs_disconnect(int connect)
  attach_function :_pbs_disconnect, :pbs_disconnect, [ :int ], :int

  # int pbs_holdjob(int connect, char *job_id, char *hold_type, char *extend)
  attach_function :_pbs_holdjob, :pbs_holdjob, [ :int, :pointer, :pointer, :pointer ], :int

  # int pbs_rlsjob(int connect, char *job_id, char *hold_type, char *extend)
  attach_function :_pbs_rlsjob, :pbs_rlsjob, [ :int, :pointer, :pointer, :pointer ], :int

  # void pbs_statfree(struct batch_status *stat)
  attach_function :_pbs_statfree, :pbs_statfree, [ :pointer ], :void

  # batch_status * pbs_statjob(int connect, char *id, struct attrl *attrib, char *extend)
  attach_function :_pbs_statjob, :pbs_statjob, [ :int, :pointer, :pointer, :pointer ], :pointer

  # batch_status * pbs_statnode(int connect, char *id, struct attrl *attrib, char *extend)
  attach_function :_pbs_statnode, :pbs_statnode, [ :int, :pointer, :pointer, :pointer ], :pointer

  # batch_status * pbs_statque(int connect, char *id, struct attrl *attrib, char *extend)
  attach_function :_pbs_statque, :pbs_statque, [ :int, :pointer, :pointer, :pointer ], :pointer

  # batch_status * pbs_statserver(int connect, struct attrl *attrib, char *extend)
  attach_function :_pbs_statserver, :pbs_statserver, [ :int, :pointer, :pointer ], :pointer

  # char *pbs_submit(int connect, struct attropl *attrib, char *script, char *destination, char *extend)
  attach_function :_pbs_submit, :pbs_submit, [ :int, :pointer, :pointer, :pointer, :pointer ], :string

  # PBS commands with no special features
  alias_method :pbs_default, :_pbs_default
  alias_method :pbs_disconnect, :_pbs_disconnect
  alias_method :pbs_statfree, :_pbs_statfree

  # PBS connect (may not set _pbs_errno, need to check for negative output)
  def pbs_connect(*args)
    tmp = _pbs_connect(*args)
    self._pbs_errno = tmp.abs if tmp < 0
    raise PBSError, "#{error}" if error?
    tmp
  end

  # PBS commands with error tracking
  %w{pbs_deljob pbs_holdjob pbs_rlsjob}.each do |method|
    define_method(method) do |*args|
      tmp = send("_#{method}".to_sym, *args)
      raise PBSError, "#{error}" if error?
      tmp
    end
  end

  # Request status of jobs with defined parameters
  # Then converts C-linked list pointers to Ruby arrays
  %w{pbs_statjob pbs_statnode pbs_statque pbs_statserver}.each do |method|
    define_method(method) do |*args|
      jobs_ptr = send("_#{method}".to_sym, *args)
      raise PBSError, "#{error}" if error?
      jobs = jobs_ptr.read_array_of_type(BatchStatus)
      jobs.each do |job|
        job[:attribs] = job[:attribs].read_array_of_type(Attrl)
      end
      _pbs_statfree(jobs_ptr) # free memory
      jobs
    end
  end

  # PBS submit has to convert a hash array to a C-linked list of structs
  def pbs_submit(connect, attropl_list, script, destination, extends)
    attropl_list = [attropl_list] unless attropl_list.is_a? Array

    prev = FFI::Pointer.new(FFI::Pointer::NULL)
    attropl_list.each do |attropl_hash|
      attropl = Attropl.new
      attropl[:name] = FFI::MemoryPointer.from_string(attropl_hash[:name] || "")
      attropl[:resource] = FFI::MemoryPointer.from_string(attropl_hash[:resource] || "")
      attropl[:value] = FFI::MemoryPointer.from_string(attropl_hash[:value] || "")
      attropl[:op] = :set
      attropl[:next] = prev
      prev = attropl
    end

    tmp = _pbs_submit(connect, prev, script, destination, extends)
    raise PBSError, "#{error}" if error?
    tmp
  end

  def error?
    !_pbs_errno.zero?
  end

  def error
    ERRORS_TXT[_pbs_errno] || "Could not find a text for this error."
  end

  def reset_error
    self._pbs_errno = 0
  end

  BatchOp = enum( :set, :unset, :incr, :decr, :eq, :ne, :ge,
                  :gt, :le, :lt, :dflt, :merge )

  class Attrl < FFI::Struct
    layout :next,       :pointer,
           :name,       :string,
           :resource,   :string,
           :value,      :string,
           :op,         BatchOp         # not used
  end

  class Attropl < FFI::Struct
    layout :next,       :pointer,
           :name,       :pointer,
           :resource,   :pointer,
           :value,      :pointer,
           :op,         BatchOp
  end

  class BatchStatus < FFI::Struct
    layout :next,       :pointer,
           :name,       :string,
           :attribs,    :pointer,       # struct attrl*
           :text,       :string
  end

  class FFI::Pointer
    def read_array_of_type(type)
      ary = []
      ptr = self
      until ptr.null?
        tmp = type.new(ptr)
        ary << Hash[tmp.members.zip(tmp.members.map {|key| tmp[key]})]
        ptr = tmp[:next]
      end
      ary
    end
  end
end
