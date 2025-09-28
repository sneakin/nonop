require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NineP::Server
  class AttachStream < Stream
    attr_reader :fs

    def initialize fs, fid
      @fs = fs
      @fid = fid
    end

    def dup
      self.class.new(fs, fid)
    end

    def close
      self
    end

    def walk path
      @fs.walk(path, 0)
    end

    def getattr mask
      @fs.getattr(0)
    end
  end
end
