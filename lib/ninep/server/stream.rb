require 'sg/ext'
using SG::Ext

module NineP::Server
  class Stream
    def close
      @closed = true
    end
    def closed?
      @closed
    end
    def authentic? username, uid
      false
    end
    def open flags
      raise Errno::ENOTSUP
    end
    def readdir count, offset = 0
      raise Errno::ENOTSUP
    end
    def read count, offset = 0
      raise Errno::ENOTSUP
    end
    def write data, offset = 0
      raise Errno::ENOTSUP
    end
    def walk path
      raise Errno::ENOTSUP
    end
    def getattr mask
      raise Errno::ENOTSUP
    end
  end
end
