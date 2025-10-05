require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NonoP::Server
  class FileStream < Stream
    # @return [FileSystem]
    attr_reader :fs
    # @return [Integer]
    attr_reader :fid
    # @return [Array<Qid>]
    attr_reader :qids
    # @return [Integer]
    attr_reader :fsid

    # @param fs [FileSystem]
    # @param fid [Integer]
    # @param qids [Array<Qid>]
    # @param fsid [Integer]
    def initialize fs, fid, qids, fsid
      @fs = fs
      @fid = fid
      @qids = qids
      @fsid = fsid
    end

    # @return [FileStream]
    def dup
      self.class.new(fs, fid, qids, fsid)
    end

    # return [Qid]
    def qid
      # todo more unique path value
      @qid ||= @qids[-1] || NonoP::Qid.new(type: NonoP::Qid::Types[:FILE],
                                           version: 0,
                                           path: (fs.fsid_path(fsid).last || '/')[0, 8])
    end

    # return [self]
    # @raise SystemCallError    
    def close
      fs.close(fsid)
      self
    end

    # @param flags [Integer]
    # @return [self]
    # @raise SystemCallError    
    def open flags
      fs.open(fsid, flags)
      self
    end

    # @abstract
    # @param name [String]
    # @param flags [Integer]
    # @param mode [Integer]
    # @param gid [Integer]
    # @return [self]
    # @raise SystemCallError
    def create name, flags, mode, gid
      fs.create(fsid, name, flags, mode, gid)
      self
    end

    # @param count [Integer]
    # @param offset [Integer]
    # @return [Array(#name, #getattr)]
    # @raise SystemCallError
    def readdir count, offset = 0
      fs.readdir(fsid, count, offset)
    end

    # @param count [Integer]
    # @param offset [Integer]
    # @return [String]
    # @raise SystemCallError
    def read count, offset = 0, &cb
      fs.read(fsid, count, offset, &cb)
    end

    # @param data [String]
    # @param offset [Integer]
    # @return [Integer]
    # @raise SystemCallError
    def write data, offset = 0
      fs.write(fsid, data, offset)
    end

    # @param path [String, RemotePath]
    # @return [Array(Array<Qid>, Integer)]
    # @raise SystemCallError
    def walk path
      fs.walk(path, fsid)
    end

    # @param mask [Integer]
    # @return [Hash(Symbol, Object)]
    # @raise SystemCallError
    def getattr mask
      fs.getattr(fsid)
    end

    # @param attrs [Hash(Symbol, Object)]
    # @return [self]
    # @raise SystemCallError
    def setattr attrs
      fs.setattr(fsid, {
                   mode: setattr_field(attrs, :MODE, :mode),
                   uid: setattr_field(attrs, :UID, :uid),
                   gid: setattr_field(attrs, :GID, :gid),
                   size: setattr_field(attrs, :SIZE, :size),
                   atime_sec: setattr_time(attrs, :ATIME, :ATIME_SET, :atime_sec),
                   atime_nsec: setattr_nsec(attrs, :ATIME, :ATIME_SET, :atime_nsec),
                   mtime_sec: setattr_time(attrs, :MTIME, :MTIME_SET, :mtime_sec),
                   mtime_nsec: setattr_nsec(attrs, :MTIME, :MTIME_SET, :mtime_nsec),
                 }.reject { _2.nil? }.tap { NonoP.vputs(_1.inspect) })
      self
    end

    private

    def setattr_value data, bit, value
      return value if 0 != (data.valid & NonoP::L2000::Tsetattr::Bits[bit])
    end

    def setattr_field data, bit, field
      setattr_value(data, bit, data[field])
    end

    def setattr_time data, now_bit, set_bit, field
      setattr_value(data, now_bit,
                    0 == (data.valid & NonoP::L2000::Tsetattr::Bits[set_bit]) ? Time.now : data[field])
    end

    def setattr_nsec data, now_bit, set_bit, field
      setattr_value(data, now_bit,
                    0 == (data.valid & NonoP::L2000::Tsetattr::Bits[set_bit]) ? Time.now.nsec : data[field])
    end
  end
end
