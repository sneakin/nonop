require 'sg/ext'
using SG::Ext

require 'nonop/qid'

module NonoP::Server::FileSystem
  class Base
    # @return [Qid]
    def qid
      @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:MOUNT],
                              version: 0, path: [ hash ].pack('Q'))
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
    # @param fsid [FSID]
    # @return [Qid]
    # @raise SystemCallError
    # @raise KeyError
    def fsid_qid fsid
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
    # @param flags [NonoP::BitField::Instance]
    # @param mode [NonoP::BitField::Instance]
    # @param gid [Integer]
    # @return [OpenedEntry]
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
    def read fsid, count, offset = 0, &cb
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
