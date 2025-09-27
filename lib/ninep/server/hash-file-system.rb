require 'sg/ext'
using SG::Ext

require_relative 'file-system'

module NineP::Server
  class HashFileSystem < FileSystem
    BLOCK_SIZE = 4096

    MODE_WRITEABLE = 0664
    MODE_READABLE = 0444
    MODE_EXECUTABLE = 0775
    
    DEFAULT_DIR_ATTRS = {
      valid: 0xFFFF, # mask of set fields
      mode: PermMode::DIR | MODE_EXECUTABLE,
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
      merge(mode: PermMode::FILE | MODE_READABLE)

    # Represents files in the HashFileSystem.
    class Entry
      # Provides a per connection interface to an Entry using a DataProvider to tailor the operations.
      class OpenedEntry
        attr_reader :entry, :mode, :data
        def initialize entry, mode, data
          @entry = entry
          @mode = mode
          @data = data
        end
        def close
          @data&.close
          @mode = @data = nil
        end
        
        delegate :truncate, :read, :write, :readdir, to: :data

        def writeable?
          (nil != @mode) &&
            ((0 != ((@mode || 0) & (NineP::L2000::Topen::Flags[:WRONLY] | NineP::L2000::Topen::Flags[:RDWR]))))
        end
        
        def readable?
          (nil != @mode) &&
            ((0 == (@mode || 0) & NineP::L2000::Topen::Mask[:MODE]) ||
             (0 != ((@mode || 0) & (NineP::L2000::Topen::Flags[:RDONLY] | NineP::L2000::Topen::Flags[:RDWR]))))
        end
      end

      # Provides the data for OpenedEntry hhat is dependent on the entry's type.
      class DataProvider
        def open mode
          self
        end
        
        def close
          self
        end
        
        def truncate size = 0
          raise Errno::ENOTSUP
        end

        def read count, offset = 0
          raise Errno::ENOTSUP
        end

        def write data, offset = 0
          raise Errno::ENOTSUP
        end
      end
      
      attr_reader :name, :umask
      
      def initialize name, umask: nil
        @name = name
        @umask = umask || File.umask
      end
      
      def qid
        @qid ||= NineP::Qid.new(type: NineP::Qid::Types[:FILE],
                                version: 0,
                                path: @name[0, 8])
      end

      def size
        0
      end

      def open p9_mode, data = nil
        OpenedEntry.new(self, p9_mode, data || DataProvider.new)
      end
      
      def close
        self
      end
      
      def attrs
        @attrs ||= DEFAULT_FILE_ATTRS.
          merge(qid: qid,
                mode: PermMode::FILE | MODE_READABLE & ~umask)
      end
      
      def getattr
        attrs.merge(size: size, blocks: size / BLOCK_SIZE)
      end
    end

    # Read only entries backed by String, Proc, or Pathname#read generated strings.
    class StaticEntry < Entry
      class DataProvider < Entry::DataProvider
        attr_reader :entry
        
        def initialize entry
          @entry = entry
        end
        
        def read count, offset = 0
          entry.attrs[:atime_sec] = Time.now
          entry.data[offset, count]
        end
      end

      def initialize name, data, umask: nil
        super(name, umask:)
        @data = data
      end

      def open p9_mode
        ret = super(p9_mode, DataProvider.new(self))
        raise Errno::ENOTSUP if ret.writeable?
        ret
      end
      
      def size
        data.bytesize
      end

      def data
        case @data
        when Proc then @data.call.to_s
        when Pathname then @data.read
        else @data
        end
      end
    end

    # File backed entry with read and write support.
    class FileEntry < Entry
      # Allows use by multiple connections by giving each connection
      # an independent IO.
      class DataProvider < Entry::DataProvider
        attr_reader :entry
        
        def initialize entry, writeable = false
          @entry = entry
          @writeable = writeable
        end

        delegate :path, to: :entry
        
        def open p9_mode = nil
          return self if @io
          
          raise Errno::ENOTSUP if (!@writeable && (0 != (p9_mode & NineP::L2000::Topen::Mask[:MODE])))
          raise Errno::ENOTSUP if (0 != (p9_mode & NineP::L2000::Topen::Flags[:DIRECTORY]))
          raise Errno::ENOENT if @writeable && (0 == (p9_mode & NineP::L2000::Topen::Flags[:CREATE])) && !path.exist?
          # todo full mapping
          mode = case p9_mode & NineP::L2000::Topen::Mask[:MODE]
                 when NineP::L2000::Topen::Flags[:RDONLY] then 'rb'
                 when NineP::L2000::Topen::Flags[:WRONLY] then 'wb'
                 when NineP::L2000::Topen::Flags[:RDWR] then 'rb+'
                 else 'rb'
                 end
          mode[0] = 'a' if 0 != (p9_mode & NineP::L2000::Topen::Flags[:APPEND])
          @io = path.open(mode)
          super
        end

        def close
          @io&.close
          @io = nil
          super
        end

        def io
          open if @io == nil
          @io
        end
        
        def read count, offset = 0
          io.seek(offset)
          io.read(count)
        end

        def truncate size = 0
          io.truncate(size)
          self
        end

        def write data, offset = 0
          io.seek(offset)
          io.write(data)
        end
      end

      # todo What happens if the io blocks? Ideally a reply finally gets sent when data is read w/o blocking any thing else.
      # todo Purely IO backed entries: open & close pose problems

      attr_reader :path
      
      def initialize name, path: nil, writeable: nil, umask: nil
        super(name, umask:)
        @path = (path == nil || Pathname === path) ? path : Pathname.new(path)
        @writeable = writeable
      end
      
      def size
        if path
          path.stat.size
        else
          0
        end
      end

      def open p9_mode = nil
        data = DataProvider.new(self, @writeable)
        data.open(p9_mode)
        super(p9_mode, data)
      end

      def attrs
        @attrs ||= DEFAULT_FILE_ATTRS.
          merge(qid: qid,
                mode: (PermMode::FILE | ((@writeable ? MODE_WRITEABLE : MODE_READABLE) & ~umask)))
      end
    end
    
    class BufferEntry < Entry
      class DataProvider < Entry::DataProvider
        attr_reader :entry
        delegate :read, :write, :truncate, to: :entry

        def initialize entry
          @entry = entry
        end
      end

      attr_accessor :data
      
      def initialize name, data, umask: nil
        super(name, umask:)
        @data = data
      end
      
      def size
        data.bytesize
      end

      def open flags
        oe = super(flags, DataProvider.new(self))
        if 0 != (flags & (NineP::L2000::Topen::Flags[:CREATE] || NineP::L2000::Topen::Flags[:TRUNC]))
          oe.truncate
        end
        oe
      end        

      def read count, offset = 0
        attrs[:atime_sec] = Time.now
        data[offset, count]
      end

      def truncate size = 0
        @data = @data[0, size]
        attrs[:ctime_sec] = Time.now
        self
      end

      def write data, offset = 0
        if offset < (@data.size - data.size)
          @data[offset, data.size] = data
        else
          @data += ("\x00" * (offset - @data.size)) + data
        end
        attrs[:mtime_sec] = Time.now
        data.size # todo bytesize?
      end

      def attrs
        @attrs ||= DEFAULT_FILE_ATTRS.
          merge(qid: qid,
                mode: PermMode::FILE | ((data.frozen? ? MODE_READABLE : MODE_WRITEABLE) & ~umask))
      end
    end
    
    # An entry that has dynamically generated contents that buffers writes for an updating callback.
    class WriteableEntry < BufferEntry
      def initialize name, umask: nil, &blk
        super(name, blk.call(self), umask:)
        @cb = blk
      end

      def write data, offset = 0
        n = super
        @cb&.call(self, data, offset)
        n
      end
    end

    class DirectoryEntry < Entry
      class DataProvider < Entry::DataProvider
        attr_reader :entry
        
        def initialize entry
          @entry = entry
        end
        
        def readdir count, offset = 0
          entry.attrs[:atime_sec] = Time.now
          entry.readdir(count, offset)
        end
      end

      attr_reader :entries
      
      def initialize name, umask: nil, entries:, root: false
        super(name, umask:)
        @is_root = root
        @entries = Hash[(entries || {}).collect { |name, data|
                          [ name,
                            case data
                            when Entry then data
                            when String then BufferEntry.new(name, data, umask: umask)
                            when Pathname then FileEntry.new(name, path: data, umask: umask)
                            when Hash then DirectoryEntry.new(name, entries: data, umask: umask)
                            else StaticEntry.new(name, data, umask: umask)
                            end
                          ]}]
      end

      def is_root?
        !!@is_root
      end
      
      def qid
        @qid ||= NineP::Qid.new(type: is_root? ? NineP::Qid::Types[:MOUNT] : NineP::Qid::Types[:DIR],
                                version: 0,
                                path: @name[0, 8])
      end

      def open p9_mode
        super(p9_mode, DataProvider.new(self))
      end
      
      def size
        entries.size
      end

      def readdir count, offset = 0
        @entries.values[offset, count] || []
      end

      def getattr
        DEFAULT_DIR_ATTRS.
          merge(qid: qid,
                size: @entries.size,
                mode: (PermMode::DIR | MODE_EXECUTABLE) & ~umask,
                blocks: @entries.size / BLOCK_SIZE)
      end
    end
    
    # Provides the operations for ~fsid~ numbers to reference an OpenedEntry.
    class FSID
      attr_accessor :path, :entry, :backend, :open_flags
      
      def initialize path, entry, open_flags: nil, backend: nil
        @path = path
        @entry = entry
        @open_flags = open_flags
        @backend = backend
      end

      def dup
        self.class.new(path, entry, open_flags:, backend: backend.dup)
      end
      
      def reading?
        m = @open_flags & NineP::L2000::Topen::Mask[:MODE]
        m == NineP::L2000::Topen::Flags[:RDONLY] ||
          m == NineP::L2000::Topen::Flags[:RDWR]
      end

      def writing?
        m = @open_flags & NineP::L2000::Topen::Mask[:MODE]
        m == NineP::L2000::Topen::Flags[:WRONLY] ||
          m == NineP::L2000::Topen::Flags[:RDWR]
      end

      def open flags
        @open_flags = flags
        @backend&.close
        @backend = @entry.open(flags)
        self
      end

      def close
        @backend&.close
        @backend = nil
        self
      end
      
      delegate :truncate, :read, :write, :readdir, to: :backend
      delegate :size, :getattr, to: :entry
    end

    attr_reader :root
    delegate :qid, :entries, to: :root
    
    def initialize entries: nil, umask: nil
      @root = DirectoryEntry.new('/', entries: entries, umask: umask, root: true)
      @next_id = 0
      @fsids = {}
    end
    
    def qid_for path
      steps, entry = find_entry(path)
      raise KeyError.new("#{path} not found") unless entry
      entry.qid
    end

    def open fsid, flags
      NineP.vputs { "Opening #{fsid} #{@fsids[fsid]}" }
      id_data = @fsids.fetch(fsid)
      id_data.open(flags)
    rescue KeyError
      raise Errno::EBADFD
    end
    
    def close fsid
      id_data = @fsids.delete(fsid)
      id_data&.close
      self
    end

    def next_id
      @next_id += 1
    end

    def fsid_path fsid
      @fsids.fetch(fsid).path
    end
    
    def walk path, old_fsid = nil
      i = next_id
      NineP.vputs { "Walking #{i} to #{path} #{old_fsid}" }
      steps, entry = find_entry(path, old_fsid != nil && old_fsid != 0 ? @fsids.fetch(old_fsid).entry : nil)
      @fsids[i] = FSID.new(entry.name, entry || steps.last)
      [ steps.collect(&:qid), i ]
    end

    def find_entry path, dir = nil
      parts = []
      head = nil
      rest = path
      dir ||= root

      while dir && !rest.empty?
        head, rest = rest.split_at(1)
        head = head.first
        NineP.vputs { "Finding #{head.inspect} / #{rest.inspect}" }
        ent = dir.entries[head]
        parts << ent if ent
        dir = ent
      end

      return [ parts, dir ]
    end

    def readdir fsid, count, offset = 0
      id_data = @fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.reading?
      id_data.readdir(count, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    def read fsid, count, offset = 0
      id_data = @fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.reading?
      id_data.read(count, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    def write fsid, data, offset = 0
      id_data = @fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.writing?
      id_data.write(data, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    def getattr fsid
      @fsids.fetch(fsid).getattr
    rescue KeyError
      raise Errno::ENOENT
    end
  end
end
