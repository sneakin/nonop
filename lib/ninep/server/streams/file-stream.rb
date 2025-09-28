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

    def setattr attrs
        @fs.setattr(@fsid, {
                    mode: setattr_field(attrs, :MODE, :mode),
                    uid: setattr_field(attrs, :UID, :uid),
                    gid: setattr_field(attrs, :GID, :gid),
                    size: setattr_field(attrs, :SIZE, :size),
                    atime_sec: setattr_time(attrs, :ATIME, :ATIME_SET, :atime_sec),
                    atime_nsec: setattr_nsec(attrs, :ATIME, :ATIME_SET, :atime_nsec),
                    mtime_sec: setattr_time(attrs, :MTIME, :MTIME_SET, :mtime_sec),
                    mtime_nsec: setattr_nsec(attrs, :MTIME, :MTIME_SET, :mtime_nsec),
                  }.reject { _2.nil? }.tap { NineP.vputs(_1.inspect) })
    end

    private

    def setattr_value data, bit, value
      return value if 0 != (data.valid & NineP::L2000::Tsetattr::Bits[bit])
    end

    def setattr_field data, bit, field
      setattr_value(data, bit, data[field])
    end

    def setattr_time data, now_bit, set_bit, field
      setattr_value(data, now_bit,
                    0 == (data.valid & NineP::L2000::Tsetattr::Bits[set_bit]) ? Time.now : data[field])
    end

    def setattr_nsec data, now_bit, set_bit, field
      setattr_value(data, now_bit,
                    0 == (data.valid & NineP::L2000::Tsetattr::Bits[set_bit]) ? Time.now.nsec : data[field])
    end
  end
end
