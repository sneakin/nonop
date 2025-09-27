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
  end
end
