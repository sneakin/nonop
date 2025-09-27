require 'sg/ext'
using SG::Ext

require 'ninep/qid'

module NineP::Server
  module PermMode
    PERMS = 0777
    DIR = 040000
    FILE = 0100000
  end

  class FileSystem
    def qid
      @qid ||= NineP::Qid.new(type: NineP::Qid::Types[:MOUNT],
                              version: 0, path: '/')
    end

    def qid_for path
      raise Errno::ENOTSUP
    end

    def open fsid, flags
      raise Errno::ENOTSUP
    end
    
    def close fsid
      self
    end

    def walk path, old_fsid = nil
      raise Errno::ENOTSUP
    end

    def readdir fsid, count, offset = 0
      raise Errno::ENOTSUP
    end

    def read fsid, count, offset = 0
      raise Errno::ENOTSUP
    end

    def write fsid, data, offset = 0
      raise Errno::ENOTSUP
    end

    def getattr fsid
      raise Errno::ENOTSUP
    end
  end
end
