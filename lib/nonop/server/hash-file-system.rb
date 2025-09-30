require 'pathname'
require 'timeout'

require 'sg/ext'
using SG::Ext

require_relative 'file-system'
require_relative '../remote-path'

module NonoP::Server
  class HashFileSystem < FileSystem
    class Entry < FileSystem::Entry
    end
    class OpenedEntry < FileSystem::OpenedEntry
    end
    
    # Read only entries backed by String, Proc, or Pathname#read generated strings.
    class StaticEntry < Entry
      class DataProvider < Entry::DataProvider
        # @return [StaticEntry]
        attr_reader :entry

        # @param entry [StaticEntry]
        def initialize entry
          @entry = entry
        end

        # @param count [Integer]
        # @param offset [Integer]
        # @return [String]
        # @raise SystemCallError
        def read count, offset = 0
          entry.attrs[:atime_sec] = Time.now
          entry.data[offset, count]
        end
      end

      # @param name [String]
      # @param data [String, Proc]
      # @param umask [Integer, nil]
      def initialize name, data, umask: nil
        super(name, umask:)
        @data = data
      end

      # @param p9_mode [Integer]
      # @return [OpenedEntry]
      # @raise SystemCallError
      def open p9_mode
        ret = super(p9_mode, DataProvider.new(self))
        raise Errno::ENOTSUP if ret.writeable?
        ret
      end

      # @return [Integer]
      def size
        data.bytesize
      end

      # @return [String]
      # @raise SystemCallError
      def data
        case @data
        when Proc then @data.call.to_s
        when Pathname then @data.read
        else @data
        end
      end
    end

    # File backed entry with read and write support.
    class PathEntry < Entry
      # Allows use by multiple connections by giving each connection
      # an independent IO.
      class DataProvider < Entry::DataProvider
        # @return [PathEntry]
        attr_reader :entry

        # @param entry [PathEntry]
        # @param writeable [Boolean]
        def initialize entry, writeable = false
          @entry = entry
          @writeable = writeable
        end

        delegate :path, to: :entry

        # @param p9_mode [Integer]
        # @return [self]
        # @raise SystemCallError
        def open p9_mode
          return self if @io

          raise Errno::ENOTSUP if (!@writeable && (0 != (p9_mode & NonoP::L2000::Topen::Mask[:MODE])))
          raise Errno::ENOENT if @writeable && (0 == (p9_mode & NonoP::L2000::Topen::Flags[:CREATE])) && !path.exist?
          # todo full mapping
          mode = case p9_mode & NonoP::L2000::Topen::Mask[:MODE]
                 when NonoP::L2000::Topen::Flags[:RDONLY] then 'rb'
                 when NonoP::L2000::Topen::Flags[:WRONLY] then 'wb'
                 when NonoP::L2000::Topen::Flags[:RDWR] then 'rb+'
                 else 'rb'
                 end
          mode[0] = 'a' if 0 != (p9_mode & NonoP::L2000::Topen::Flags[:APPEND])
          @io = path.open(mode)
          super
        end

        # @return [self]
        def close
          @io&.close
          @io = nil
          super
        end

        # @return [IO, nil]
        # @raise SystemCallError
        def io
          # fixme
          # open if @io == nil
          raise Errno::EBADFD unless @io
          @io
        end

        # @param size [Integer]
        # @return [self]
        # @raise SystemCallError
        def truncate size = 0
          io.truncate(size)
          self
        end

        # @param count [Integer]
        # @param offset [Integer]
        # @return [String]
        # @raise SystemCallError
        def read count, offset = 0
          io.seek(offset)
          io.read(count)
        end

        # @param data [String]
        # @param offset [Integer]
        # @return [Integer]
        # @raise SystemCallError
        def write data, offset = 0
          io.seek(offset)
          io.write(data)
        end

        # @param count [Integer]
        # @param offset [Integer]
        # @return [Array<Dirent>]
        # @raise SystemCallError
        def readdir count, offset = 0
          entry.readdir(count, offset)
        end
      end

      # todo What happens if the io blocks? Ideally a reply finally gets sent when data is read w/o blocking any thing else.
      # todo Purely IO backed entries: open & close pose problems

      # @return [RemotePath, nil]
      attr_reader :path

      # @param name [String]
      # @param path [RemotePath, nil]
      # @param writeable [Boolean]
      # @param umask [Integer, nil]
      def initialize name, path, writeable: false, umask: nil
        super(name, umask:)
        @path = Pathname === path ? path : Pathname.new(path)
        @writeable = writeable
      end

      def qid
        @qid ||= NonoP::Qid.new(type: path.directory? ? NonoP::Qid::Types[:DIR] : NonoP::Qid::Types[:FILE],
                                version: 0,
                                path: name.to_s[0, 8])
      end
      
      # @return [Integer]
      def size
        if path
          path.stat.size
        else
          0
        end
      end

      # @param p9_mode [Integer]
      # @return [OpenedEntry]
      def open p9_mode
        data = DataProvider.new(self, @writeable)
        data.open(p9_mode)
        super(p9_mode, data)
      end

      # @return [Hash<String, Entry>]
      def entries
        mtime = path.stat.mtime
        if @entries == nil || (@last_listing && @last_listing < mtime)
          Timeout.timeout(10) do
            @entries = path.children.reject { %w{. ..}.include?(_1.basename) }.collect do |child|
              name = child.basename.to_s
              if child.mountpoint?
                DirectoryEntry.new(name, umask: umask)
              else
                self.class.new(name, child, writeable: @writeable, umask: umask)
              end
            end.reduce({}) do |acc, ent|
              acc[ent.name] = ent
              acc
            end
            @last_listing = mtime
          end
        end
        
        @entries
      end

      def directory?
        path.directory?
      end
            
      def fifo?
        path.directory?
      end
            
      # @param count [Integer]
      # @param offset [Integer]
      # @return [Array<Dirent>]
      # @raise SystemCallError
      def readdir count, offset = 0
        (entries.values[offset, count] || []).each_with_index.collect do |child, n|
          NonoP::L2000::Rreaddir::Dirent.for_entry(child, n)
        end
      end

      # @return [Hash<Symbol, Object>]
      # @raise SystemCallError
      def attrs
        stat = path.stat
        { valid: -1,
          qid: qid,
          gen: 0,
          data_version: 0,
          dev: stat.dev,
          ino: stat.ino,
          mode: stat.mode & ~(@writeable ? 0 : PermMode::W),
          nlink: stat.nlink,
          uid: stat.uid,
          gid: stat.gid,
          rdev: stat.rdev,
          size: stat.size,
          blksize: stat.blksize,
          blocks: stat.blocks,
          atime_sec: stat.atime.to_i,
          atime_nsec: stat.atime.nsec,
          mtime_sec: stat.mtime.to_i,
          mtime_nsec: stat.mtime.nsec,
          ctime_sec: stat.ctime.to_i,
          ctime_nsec: stat.ctime.nsec,
          btime_sec: 0,
          btime_nsec: 0,
        }
      end

      # @param attrs [Hash<Symbol, Object>]
      # @return [self]
      # @raise SystemCallError
      def setattr attrs
        raise Errno::ENOTSUP unless @writeable
        self
      end

    end

    class BufferEntry < Entry
      class DataProvider < Entry::DataProvider
        # @return [BufferEntry]
        attr_reader :entry
        delegate :read, :write, :truncate, to: :entry

        # @param entry [BufferEntry]
        def initialize entry
          @entry = entry
        end
      end

      # @return [String]
      attr_accessor :data

      # @param name [String]
      # @param data [String]
      # @param umask [Integer, nil]
      def initialize name, data, umask: nil
        super(name, umask:)
        @data = data
      end

      # @return [Integer]
      def size
        data.bytesize
      end

      # @param flags [Integer]
      # @return [OpenedEntry]
      # @raise SystemCallError
      def open flags
        oe = super(flags, DataProvider.new(self))
        if 0 != (flags & (NonoP::L2000::Topen::Flags[:CREATE] || NonoP::L2000::Topen::Flags[:TRUNC]))
          oe.truncate
        end
        oe
      end

      # @param count [Integer]
      # @param offset [Integer]
      # @return [String]
      # @raise SystemCallError
      def read count, offset = 0
        attrs[:atime_sec] = Time.now
        data[offset, count]
      end

      # @param size [Integer]
      # @return [self]
      # @raise SystemCallError
      def truncate size = 0
        @data = @data[0, size]
        attrs[:ctime_sec] = Time.now
        self
      end

      # @param data [String]
      # @param offset [Integer]
      # @return [Integer]
      # @raise SystemCallError
      def write data, offset = 0
        if offset < (@data.size - data.size)
          @data[offset, data.size] = data
        else
          @data += ("\x00" * (offset - @data.size)) + data
        end
        attrs[:mtime_sec] = Time.now
        data.size # todo bytesize?
      end

      # @return [Hash<Symbol, Object>]
      def attrs
        @attrs ||= FileSystem::DEFAULT_FILE_ATTRS.
          merge(qid: qid,
                mode: PermMode::FILE | ((data.frozen? ? PermMode::R : PermMode::RW) & ~umask))
      end

      # @param new_attrs [Hash<Symbol, Object>]
      # @return [self]
      def setattr new_attrs
        @attrs = attrs.merge(new_attrs) # todo be picky
        self
      end
    end

    # An entry that has dynamically generated contents that buffers writes for an updating callback.
    class WriteableEntry < BufferEntry
      # @param name [String]
      # @param umask [Integer, nil]
      # @yield [entry, data, offset]
      # @yieldparam entry [WriteableEntry]
      # @yieldparam data [String, nil]
      # @yieldparam offset [Integer, nil]
      # @yieldreturn [String] The new file contents.
      def initialize name, umask: nil, &blk
        super(name, blk.call(self), umask:)
        @cb = blk
      end

      # @param data [String]
      # @param offset [Integer]
      # @return [Integer]
      # @raise SystemCallError
      def write data, offset = 0
        n = super
        @cb&.call(self, data, offset)
        n
      end
    end

    # An entry that stores data per write in a FIFO.
    class FifoEntry < Entry
      # @param name [String]
      # @param umask [Integer, nil]
      # @yield [entry, data, offset]
      # @yieldparam entry [WriteableEntry]
      # @yieldparam data [String, nil]
      # @yieldparam offset [Integer, nil]
      # @yieldreturn [String] The new file contents.
      def initialize name, umask: nil, &blk
        super(name, blk.call(self), umask:)
        @cb = blk
      end

      class DataProvider < Entry::DataProvider
        # @return [BufferEntry]
        attr_reader :entry
        delegate :read, :write, :truncate, to: :entry

        # @param entry [BufferEntry]
        def initialize entry
          @entry = entry
        end
      end

      # @return [String]
      attr_accessor :data

      # @param name [String]
      # @param data [String]
      # @param umask [Integer, nil]
      def initialize name, umask: nil
        super(name, umask:)
        @data = []
      end

      # @return [Qid]
      def qid
        @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:APPEND],
                                version: 0,
                                path: name[0, 8])
      end
      
      # @return [Integer]
      def size
        data.collect(&:bytesize).sum
      end
      
      # @return [Boolean]
      def fifo?
        true
      end

      # @param flags [Integer]
      # @return [OpenedEntry]
      # @raise SystemCallError
      def open flags
        super(flags, DataProvider.new(self))
      end

      # @param count [Integer]
      # @param offset [Integer]
      # @return [String]
      # @raise SystemCallError
      def read count, offset = 0
        return '' if data.empty?
        attrs[:atime_sec] = Time.now
        data.shift[0, count]
      end

      # @param size [Integer]
      # @return [self]
      # @raise SystemCallError
      def truncate size = 0
        @data.clear
        attrs[:ctime_sec] = Time.now
        self
      end

      # @param data [String]
      # @param offset [Integer]
      # @return [Integer]
      # @raise SystemCallError
      def write data, offset = 0
        @data.push(data)
        attrs[:mtime_sec] = Time.now
        @cb&.call(self, data, offset)
        data.size # todo bytesize?
      end

      # @return [Hash<Symbol, Object>]
      def attrs
        @attrs ||= FileSystem::DEFAULT_FILE_ATTRS.
          merge(qid: qid,
                mode: PermMode::FIFO | (PermMode::RW & ~umask))
      end

      # @param new_attrs [Hash<Symbol, Object>]
      # @return [self]
      def setattr new_attrs
        @attrs = attrs.merge(new_attrs) # todo be picky
        self
      end
    end

    class DirectoryEntry < Entry
      class DataProvider < Entry::DataProvider
        # @return [DirectoryEntry]
        attr_reader :entry

        # @param entry [DirectoryEntry]
        def initialize entry
          @entry = entry
        end

        # @param count [Integer]
        # @param offset [Integer]
        # @return [Array<Dirent>]
        # @raise SystemCallError
        def readdir count, offset = 0
          entry.attrs[:atime_sec] = Time.now
          entry.readdir(count, offset)
        end
      end

      # @return [Hash<String, Entry>]
      attr_reader :entries

      # @param name [String]
      # @param entries [Hash<String, Object>]
      # @param root [Boolean]
      # @param umask [Integer, nil]
      # @param writeable [Boolean]
      def initialize name, umask: nil, entries: nil, root: false, writeable: false
        super(name, umask:)
        @is_root = root
        @writeable = writeable
        @entries = Hash[(entries || {}).collect { |name, data|
                          [ name,
                            case data
                            when Entry then data.tap { _1.umask = umask }
                            when String then (data.frozen? ? StaticEntry : BufferEntry).new(name, data, umask: umask)
                            when Pathname then PathEntry.new(name, data, umask: umask)
                            when Hash then DirectoryEntry.new(name, entries: data, umask: umask)
                            else StaticEntry.new(name, data, umask: umask)
                            end
                          ]}]
      end

      # @return [Boolean]
      def writeable?
        !!@writeable
      end
      
      # @return [Boolean]
      def is_root?
        !!@is_root
      end

      # @return [Qid]
      def qid
        @qid ||= NonoP::Qid.new(type: is_root? ? NonoP::Qid::Types[:MOUNT] : NonoP::Qid::Types[:DIR],
                                version: 0,
                                path: name[0, 8])
      end
      
      # @return [Boolean]
      def directory?
        true
      end

      # @param p9_mode [Integer]
      # @return [OpenedEntry]
      # @raise SystemCallError
      def open p9_mode
        super(p9_mode, DataProvider.new(self))
      end

      # @return [Integer]
      def size
        entries.size
      end

      # @param count [Integer]
      # @param offset [Integer]
      # @return [Array<Dirent>]
      # @raise SystemCallError
      def readdir count, offset = 0
        @entries.values[offset, count] || []
      end

      # @return [Hash<Symbol, Object>]
      # @raise SystemCallError
      def getattr
        FileSystem::DEFAULT_DIR_ATTRS.
          merge(qid: qid,
                size: @entries.size,
                mode: PermMode::DIR | ((writeable?? PermMode::RWX : PermMode::RX) & ~umask),
                blocks: @entries.empty?? 0 : (1 + @entries.size / FileSystem::BLOCK_SIZE))
      end

      # @param name [String]
      # @param flags [Integer]
      # @param mode [Integer]
      # @param gid [Integer]
      # @return [OpenedEntry]
      def create name, flags, mode, gid
        raise Errno::ENOTSUP unless writeable?
        ent = @entries[name] = BufferEntry.new(name, '', umask: umask)
        attrs = {}
        attrs[:gid] = gid if gid
        attrs[:mode] = PermMode::FILE | (mode & ~umask) if mode
        ent.setattr(attrs) unless attrs.empty?
        ent.open(flags)
      end
    end

    # Provides the operations for ~fsid~ numbers to reference an OpenedEntry.
    class FSID
      # @return [RemotePath]
      attr_accessor :path
      # @return [Entry]
      attr_accessor :entry
      # @return [OpenedEntry, nil]
      attr_accessor :backend
      # @return [Integer, nil]
      attr_accessor :open_flags

      # @param path [RemotePath]
      # @param entry [Entry]
      # @param open_flags [Integer, nil]
      # @param backend [OpenedEntry, nil]
      def initialize path, entry, open_flags: nil, backend: nil
        @path = path
        @entry = entry
        @open_flags = open_flags
        @backend = backend
      end

      # @return [FSID]
      def dup
        self.class.new(path, entry, open_flags:, backend: backend.dup)
      end

      # @return [Boolean]
      def reading?
        m = open_flags & NonoP::L2000::Topen::Mask[:MODE]
        m == NonoP::L2000::Topen::Flags[:RDONLY] ||
          m == NonoP::L2000::Topen::Flags[:RDWR]
      end

      # @return [Boolean]
      def writing?
        m = open_flags & NonoP::L2000::Topen::Mask[:MODE]
        m == NonoP::L2000::Topen::Flags[:WRONLY] ||
          m == NonoP::L2000::Topen::Flags[:RDWR]
      end

      # @return [self]
      def open flags
        @open_flags = flags
        backend&.close
        @backend = entry.open(flags)
        self
      end

      # @return [self]
      def close
        backend&.close
        @backend = nil
        self
      end

      # @param name [String]
      # @param flags [Integer]
      # @param mode [Integer]
      # @param gid [Integer]
      # @return [self]
      def create name, flags, mode, gid
        @open_flags = flags
        backend&.close
        @backend = entry.create(name, flags, mode, gid)
        self
      end

      delegate :truncate, :read, :write, :readdir, to: :backend
      delegate :size, :getattr, :setattr, to: :entry
    end

    # @return [DirectoryEntry]
    attr_reader :root
    delegate :qid, :entries, to: :root

    # @return [Hash<Integer, FSID>]
    attr_reader :fsids

    # @param entries [Hash<String, Object>, nil]
    # @param umask [Integer, nil]
    def initialize root: nil, entries: nil, umask: nil
      @root = root || DirectoryEntry.new('/', entries: entries, umask: umask, root: true)
      @next_id = 0
      @fsids = {}
    end

    # @param path [Array<String>, RemotePath]
    # @return [Qid]
    def qid_for path
      steps, entry = find_entry(path)
      raise KeyError.new("#{path} not found") unless entry
      entry.qid
    end

    # @param fsid [Integer]
    # @param flags [Integer]
    # @return [Integer]
    def open fsid, flags
      NonoP.vputs { "Opening #{fsid} #{fsids[fsid]}" }
      id_data = fsids.fetch(fsid)
      id_data.open(flags)
      fsid
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @return [self]
    def close fsid
      id_data = fsids.delete(fsid)
      id_data&.close
      self
    end

    # @param fsid [Integer]
    # @param name [String]
    # @param flags [Integer]
    # @param mode [Integer]
    # @param gid [Integer]
    # @return [Integer]
    def create fsid, name, flags, mode, gid
      id_data = fsids.fetch(fsid)
      id_data.create(name, flags, mode, gid)
      fsid
    rescue KeyError
      raise Errno::EBADFD
    end

    # @return [Integer]
    def next_id
      @next_id += 1
    end

    # @param fsid [Integer]
    # @return [RemotePath]
    def fsid_path fsid
      fsids.fetch(fsid).path
    end

    # @param path [String, Array<String>, RemotePath]
    # @param old_fsid [Integer, nil]
    # @return [Array(Array<Qid>, Integer)]
    # @raise SystemCallError
    # @raise KeyError
    def walk path, old_fsid = nil
      path = RemotePath.new(path) if String === path
      i = next_id
      NonoP.vputs { "Walking #{i} to #{path} #{old_fsid}" }
      steps, entry = find_entry(path, old_fsid != nil && old_fsid != 0 ? fsids.fetch(old_fsid).entry : nil)
      fsids[i] = if entry
                    FSID.new(path, entry)
                  else
                    FSID.new(path, steps.last || root)
                  end
      [ steps.collect(&:qid), i ]
    end

    # @param path [String, Array<String>, RemotePath]
    # @param dir [Entry, nil]
    # @return [Array(Array<Qid>, Entry)]
    def find_entry path, dir = nil
      return find_entry(RemotePath.new(path), dir) if String === path
      
      parts = []
      head = nil
      rest = path
      dir ||= root

      while dir && !rest.empty?
        head, rest = rest.split_at(1)
        head = head.first
        NonoP.vputs { "Finding #{head.inspect} / #{rest.inspect}" }
        ent = dir.entries[head]
        parts << ent if ent
        dir = ent
      end

      return [ parts, dir ]
    end

    # @param fsid [Integer]
    # @param count [Integer]
    # @param offset [Integer]
    # @return [Array<Entry>]
    # @raise SystemCallError
    # @raise KeyError
    def readdir fsid, count, offset = 0
      id_data = fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.reading?
      id_data.readdir(count, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @param count [Integer]
    # @param offset [Integer]
    # @return [String]
    # @raise SystemCallError
    # @raise KeyError
    def read fsid, count, offset = 0
      id_data = fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.reading?
      id_data.read(count, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @param data [String]
    # @param offset [Integer]
    # @return [Integer]
    # @raise SystemCallError
    # @raise KeyError
    def write fsid, data, offset = 0
      id_data = fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.writing?
      id_data.write(data, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @return [Hash<Symbol, Object>]
    # @raise SystemCallError
    # @raise KeyError
    def getattr fsid
      NonoP.vputs { "GetAttr #{fsid} #{fsids[fsid].inspect}" }
      fsids.fetch(fsid).getattr
    rescue KeyError
      if fsid == 0
        root.getattr
      else
        raise Errno::EBADFD
      end
    end

    # @param fsid [Integer]
    # @param attrs [Hash<Symbol, Object>]
    # @return [self]
    # @raise SystemCallError
    # @raise KeyError
    def setattr fsid, attrs
      NonoP.vputs { "SetAttr #{fsid} #{fsids[fsid].inspect}" }
      fsids.fetch(fsid).setattr(attrs)
      self
    rescue KeyError
      raise Errno::EBADFD
    end
  end
end
