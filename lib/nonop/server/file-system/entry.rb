require 'sg/ext'
using SG::Ext

require 'nonop/qid'
require 'nonop/perm-mode'

module NonoP::Server::FileSystem
  # Represents files in the FileSystem.
  class Entry
    # Provides the data for OpenedEntry hhat is dependent on the entry's type.
    class DataProvider
      # @return [NonoP::BitField::Instance]
      attr_reader :mode

      # @return [Boolean]
      def writeable?
        (nil != mode) &&
          (mode & [ :WRONLY, :RDWR ])
      end

      # @return [Boolean]
      def readable?
        (nil != mode) &&
          ((0 == mode.mask(NonoP::OpenFlags[:MODE])) ||
           (mode & [ :RDONLY, :RDWR ]))
      end

      # @return [Boolean]
      def appending?
        (nil != mode) && (mode & :APPEND)
      end
      
      # @abstract
      # @param mode [NonoP::BitField::Instance]
      # @return [self]
      # @raise SystemCallError
      def open mode
        @mode = NonoP::OpenFlags.new(mode)
        self
      end

      # @abstract
      # @return [self]
      # @raise SystemCallError
      def close
        self
      end

      # @abstract
      # @param size [Integer]
      # @return [self]
      # @raise SystemCallError
      def truncate size = 0
        raise Errno::ENOTSUP
      end

      # @abstract
      # @param count [Integer]
      # @param offset [Integer]
      # @yield [void]
      # @yieldreturn [String] Read data
      # @return [String]
      # @raise SystemCallError
      def read count, offset = 0, &cb
        raise Errno::ENOTSUP
      end

      # @abstract
      # @param data [String]
      # @param offset [Integer]
      # @return [Integer]
      # @raise SystemCallError
      def write data, offset = 0
        raise Errno::ENOTSUP
      end

      # @abstract
      # @param count [Integer]
      # @param offset [Integer]
      # @return [Array<Dirent>]
      # @raise SystemCallError
      def readdir count, offset = 0
        raise Errno::ENOTSUP
      end
    end

    # @return [String]
    attr_reader :name
    # @return  [Integer, nil]
    attr_accessor :umask

    # @param name String
    # @param umask [Integer, nil]
    def initialize name, umask: nil
      @name = name
      @umask = umask || 0
    end

    def info_hash
      { kind: self.class.name, name: name, qid: qid, size: size }
    end
    
    # @return [Qid]
    def qid
      @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:FILE],
                              version: 0,
                              path: [ hash ].pack('Q'))
    end

    # @abstract
    # @return [Integer]
    def size
      0
    end

    # @abstract
    # @return [Boolean]
    def directory?
      false
    end

    # @abstract
    # @return [Boolean]
    def pipe?
      false
    end
    
    # @abstract
    # @param p9_mode [NonoP::BitField::Instance]
    # @param data [DataProvider, nil]
    # @return [OpenedEntry]
    # @raise SystemCallError
    def open p9_mode, data = nil
      data ||= DataProvider.new(self)
      data.open(p9_mode)
      OpenedEntry.new(self, data)
    end

    # @abstract
    # @return [self]
    # @raise SystemCallError
    def close
      self
    end

    # @abstract
    # @param name String
    # @param flags [NonoP::BitField::Instance]
    # @param mode [NonoP::BitField::Instance]
    # @param gid [Integer]
    # @return [OpenedEntry]
    # @raise SystemCallError
    def create name, flags, mode, gid
      raise Errno::ENOTSUP
    end

    # @return [Hash<Symbol, Object>]
    def attrs
      @attrs ||= DEFAULT_FILE_ATTRS.
        merge(qid: qid,
              mode: NonoP::PermMode[:FILE] | NonoP::PermMode[:R] & ~umask)
    end

    # @abstract
    # @return [Hash<Symbol, Object>]
    # @raise SystemCallError
    def getattr
      attrs.merge(size: size,
                  blocks: size == 0 ? 0 : (1 + size / BLOCK_SIZE))
    end

    # @abstract
    # @param attrs [Hash<Symbol, Object>]
    # @return [self]
    # @raise SystemCallError
    def setattr attrs
      raise Errno::ENOTSUP
    end
  end
end
