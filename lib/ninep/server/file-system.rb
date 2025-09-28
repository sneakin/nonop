require 'sg/ext'
using SG::Ext

require 'ninep/qid'
require 'ninep/remote-path'

module NineP::Server
  module PermMode
    PERMS = 0777
    DIR = 040000
    FILE = 0100000
  end

  class FileSystem
    # @return [Qid]
    def qid
      @qid ||= NineP::Qid.new(type: NineP::Qid::Types[:MOUNT],
                              version: 0, path: '/')
    end

    # @abstract
    # @param path [Array<String>, RemotePath]
    # @return [Qid]
    # @raise SystemCallError
    # @raise KeyError
    def qid_for path
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param fsid [Integer]
    # @param flags [Integer]
    # @return [Boolean]
    # @raise SystemCallError
    # @raise KeyError
    def open fsid, flags
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param fsid [Integer]
    # @return [self]
    # @raise SystemCallError
    # @raise KeyError
    def close fsid
      self
    end

    # @abstract
    # @param fsid [Integer]
    # @param name String
    # @param flags [Integer]
    # @param mode [Integer]
    # @param gid [Integer]
    # @return [Boolean]
    # @raise SystemCallError
    # @raise KeyError
    def create fsid, name, flags, mode, gid
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param path [String, RemotePath]
    # @param old_fsid [Integer, nil]
    # @return [Array(Array<Qid>, Integer)]
    # @raise SystemCallError
    # @raise KeyError
    def walk path, old_fsid = nil
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param fsid [Integer]
    # @param count [Integer]
    # @param offset [Integer]
    # @return [Array<Entry>]
    # @raise SystemCallError
    # @raise KeyError
    def readdir fsid, count, offset = 0
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param fsid [Integer]
    # @param count [Integer]
    # @param offset [Integer]
    # @return [String]
    # @raise SystemCallError
    # @raise KeyError
    def read fsid, count, offset = 0
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param fsid [Integer]
    # @param data [String]
    # @param offset [Integer]
    # @return [Integer]
    # @raise SystemCallError
    # @raise KeyError
    def write fsid, data, offset = 0
      raise Errno::ENOTSUP
    end

    # @todo File stat structure insteadbof open hashes
    # @abstract
    # @param fsid [Integer]
    # @return [Hash<Symbol, Object>]
    # @raise SystemCallError
    # @raise KeyError
    def getattr fsid
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param fsid [Integer]
    # @param attrs [Hash<Symbol, Object>]
    # @return [self]
    # @raise SystemCallError
    # @raise KeyError
    def setattr fsid, attrs
      raise Errno::ENOTSUP
    end
  end
end
