require 'sg/ext'
using SG::Ext

module NonoP::Server
  class Stream
    # @abstract
    # @return [Qid]
    def qid
      @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:FILE],
                              version: 0,
                              path: hash)
    end

    # @abstract
    # @return [self]
    def close
      @closed = true
      self
    end

    # return [Boolean]
    def closed?
      @closed
    end

    # @abstract
    # @param username [String]
    # @param uid [Integer]
    # @return [Boolean]
    def authentic? username, uid
      false
    end

    # @abstract
    # @param flags [Integer]
    # @return [self]
    # @raise SystemCallError
    def open flags
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param name [String]
    # @param flags [Integer]
    # @param mode [Integer]
    # @param gid [Integer]
    # @return [self]
    # @raise SystemCallError
    def create name, flags, mode, gid
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param count [Integer]
    # @param offset [Integer]
    # @return [Array(#name, #getattr)]
    # @raise SystemCallError
    def readdir count, offset = 0
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param count [Integer]
    # @param offset [Integer]
    # @return [String]
    # @raise SystemCallError
    def read count, offset = 0, &cb
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param data [String]
    # @param offset [Integer]
    # @yield [count]
    # @yieldparam count [Integer]
    # @return [Integer, void]
    # @raise SystemCallError
    def write data, offset = 0, &cb
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param path [String, RemotePath]
    # @return [Array(Array<Qid>, Integer)]
    # @raise SystemCallError
    def walk path
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param mask [Integer]
    # @return [Hash(Symbol, Object)]
    # @raise SystemCallError
    def getattr mask
      raise Errno::ENOTSUP
    end

    # @abstract
    # @param attrs [Hash(Symbol, Object)]
    # @return [self]
    # @raise SystemCallError
    def setattr attrs
      raise Errno::ENOTSUP
    end

    # @abstract
    # @return [Hash(Symbol, Obkect)]
    def statfs
      raise Errno::ENOTSUP
    end
  end
end
