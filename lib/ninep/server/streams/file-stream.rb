require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NineP::Server
  class FileStream < Stream
    attr_reader :fs, :fid, :qids, :fsid
    
    def initialize fs, fid, qids, fsid
      @fs = fs
      @fid = fid
      @qids = qids
      @fsid = fsid
    end

    def dup
      self.class.new(fs, fid, qids, fsid)
    end

    def qid
      @qid ||= @qids[-1] || NineP::Qid.new(type: NineP::Qid::Types[:FILE], version: 0, path: @fs.fsid_path(@fsid)[0, 8])
    end

    def close
      @fs.close(@fsid)
    end

    def open flags
      @fs.open(@fsid, flags)
    end

    def create name, flags, mode, gid
      @fs.create(@fsid, name, flags, mode, gid)
    end
    
    def readdir count, offset = 0
      @fs.readdir(@fsid, count, offset)
    end

    def read count, offset = 0
      @fs.read(@fsid, count, offset)
    end

    def write data, offset = 0
      @fs.write(@fsid, data, offset)
    end

    def walk path
      @fs.walk(path, @fsid)
    end

    def getattr mask
      @fs.getattr(@fsid)
    end

    def setattr_bit data, bit, field
      return data[field] if 0 != (data.valid & NineP::L2000::Tsetattr::Bits[bit])
    end
    
    def setattr attrs
      @fs.setattr(@fsid, {
                    mode: setattr_bit(attrs, :MODE, :mode),
                    uid: setattr_bit(attrs, :UID, :uid),
                    gid: setattr_bit(attrs, :GID, :gid),
                    size: setattr_bit(attrs, :SIZE, :size),
                    atime_sec: setattr_bit(attrs, :ATIME_SET, :atime_sec),
                    atime_nsec: setattr_bit(attrs, :ATIME_SET, :atime_nsec),
                    mtime_sec: setattr_bit(attrs, :MTIME_SET, :mtime_sec),
                    mtime_nsec: setattr_bit(attrs, :MTIME_SET, :mtime_nsec),
                  }.reject { _2.nil? }.tap { NineP.vputs(_1.inspect) })
    end
  end
end
