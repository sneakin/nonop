require 'sg/ext'
using SG::Ext

require 'nonop/qid'
require 'nonop/remote-path'
require 'nonop/perm-mode'

module NonoP::Server
  class FileSystem
    BLOCK_SIZE = 4096

    DEFAULT_DIR_ATTRS = {
      valid: 0xFFFF, # mask of set fields
      mode: NonoP::PermMode[:DIR] | NonoP::PermMode[:RWX],
      uid: Process.uid,
      gid: Process.gid,
      nlink: 1,
      rdev: 0,
      blksize: BLOCK_SIZE,
      atime_sec: Time.now,
      atime_nsec: 0,
      mtime_sec: Time.now,
      mtime_nsec: 0,
      ctime_sec: Time.now,
      ctime_nsec: 0,
      btime_sec: Time.now,
      btime_nsec: 0,
      gen: 0,
      data_version: 0
    }

    DEFAULT_FILE_ATTRS = DEFAULT_DIR_ATTRS.
      merge(mode: NonoP::PermMode[:FILE] | NonoP::PermMode[:R])

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
            ((0 == mode.mask(NonoP::L2000::Topen::Mask[:MODE])) ||
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
          @mode = NonoP::L2000::Topen::FlagField.new(mode)
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

    # Provides a per connection interface to an Entry using a DataProvider to tailor the operations.
    class OpenedEntry
      # @return [Entry]
      attr_reader :entry
      # @return [Entry::DataProvider]
      attr_reader :data

      # @param entry [Entry]
      # @param data [Entry::DataProvider]
      def initialize entry, data
        @entry = entry
        @data = data
      end

      # @return [self]
      def close
        @data&.close
        @data = nil
        self
      end

      delegate :truncate, :read, :write, :readdir, :writeable?, :readable?, :appending?, to: :data

    end

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
