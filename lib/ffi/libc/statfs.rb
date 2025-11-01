require 'pathname'
require 'ffi'

module FFI::LibC
  extend FFI::Library
  ffi_lib 'c'
  class StatFS < FFI::Struct
    layout(:type, :long,
           :bsize, :ulong,
           :blocks, :ulong,
           :bfree, :ulong,
           :bavail, :ulong,
           :files, :ulong,
           :ffree, :ulong,
           :fsid, :ulong_long,
           :namelen, :long,
           :frsize, :long,
           :flags, :long,
           :spare, [:long, 4])

    members.each { attr _1 }
    
    def to_hash
      members.reduce({}) { _1[_2] = self[_2]; _1 }
    end

    def fetch key
      self[key]
    end

    def each &blk
      return to_enum(__method__) unless blk
      if blk.arity == 1
        members.each { blk.call([_1, self[_1]]) }
      else
        members.each { blk.call(_1, self[_1]) }
      end
    end
  end

  attach_function :statfs, [ :string, StatFS.by_ref ], :int
end
