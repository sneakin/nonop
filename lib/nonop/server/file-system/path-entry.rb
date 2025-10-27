require 'sg/ext'
using SG::Ext

require 'pathname'

module NonoP::Server::FileSystem
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

      # @return [Boolean]
      def appending?
        super || path.pipe?
      end
      
      # @param p9_mode [NonoP::BitField::Instance]
      # @return [self]
      # @raise SystemCallError
      def open p9_mode
        raise TypeError.new('boom') if ENV['BOOM'] =~ /open/
        return self if @io
        NonoP.vputs { "Opening #{self} #{path} #{p9_mode}" }

        raise Errno::ENOTSUP if (!@writeable && (0 != (p9_mode.value & NonoP::OpenFlags[:MODE])))
        raise Errno::ENOENT if @writeable && (p9_mode & :CREATE) && !path.exist?
        # todo full mapping
        mode = case p9_mode.value & NonoP::OpenFlags[:MODE]
               when NonoP::OpenFlags[:RDONLY] then 'rb'
               when NonoP::OpenFlags[:WRONLY] then 'wb'
               when NonoP::OpenFlags[:RDWR] then 'rb+'
               else 'rb'
               end
        mode[0] = 'a' if (p9_mode & :APPEND) # || path.pipe?
        mode[2] = '+' if path.pipe?
        NonoP.vputs { "   mode #{mode}" }
        
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
      # @yield [data]
      # @yieldparam data [String]
      # @yieldreturn [String]
      # @return [String, void]
      # @raise SystemCallError
      def read count, offset = 0, &cb
        # fixme deadlock on pipes, the open may be the blocker
        # fixme unable to seek fifos
        raise TypeError.new('boom') if ENV['BOOM'] =~ /read/
        NonoP.vputs { "Reading #{count}@#{offset} From #{io}" }
        if cb
          SG::IO::Reactor::BasicInput.read(io) do
            io.seek(offset) unless appending?
            io.read_nonblock(count).tap { cb.call(_1) }
          rescue EOFError
            cb.call('')
          rescue
            cb.err!($!)
          end
        else
          io.seek(offset) unless appending?
          io.read(count)
        end
      end

      # @param data [String]
      # @param offset [Integer]
      # @yield [count]
      # @yieldparam count [Integer]
      # @yieldreturn [Integer]
      # @return [Integer, void]
      # @raise SystemCallError
      def write data, offset = 0, &cb
        NonoP.vputs { "Writing #{data.bytesize}@#{offset} to #{io}" }
        if cb
          SG::IO::Reactor::BasicOutput.write(io) do
            io.seek(offset) unless appending?
            io.write_nonblock(data).tap { cb.call(_1) }
          rescue
            cb.err!($!)
          end
        else
          io.seek(offset) unless appending?
          io.write(data)
        end
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

    def info_hash
      super.merge({ path: @path.to_s, writeable: writeable? })
    end
    
    def qid
      @qid ||= NonoP::Qid.new(type: path.directory? ? NonoP::Qid::Types[:DIR] : NonoP::Qid::Types[:FILE],
                              version: 0,
                              path: [ hash ].pack('Q'))
    end
    
    # @return [Integer]
    def size
      if path
        path.stat.size
      else
        0
      end
    end

    # @return [Boolean]
    def writeable?
      !!@writeable
    end
    
    # @param p9_mode [NonoP::BitField::Instance]
    # @return [OpenedEntry]
    def open p9_mode
      data = DataProvider.new(self, @writeable)
      super(p9_mode, data)
    end

    def in_mtab? path
      path = path.expand_path.to_s
      File.open('/proc/mounts') do |io|
        io.each_line do |line|
          return true if line.split[1] == path
        end
      end
      
      false
    end
    
    # @return [Hash<String, Entry>]
    def entries
      path.children.reject { %w{. ..}.include?(_1.basename) }.collect do |child|
        name = child.basename.to_s
        if in_mtab?(child)
          DirectoryEntry.new(name, umask: umask)
        else
          self.class.new(name, child, writeable: @writeable, umask: umask)
        end
      end.reduce({}) do |acc, ent|
        acc[ent.name] = ent
        acc
      end
    end

    # @return [Boolean]
    def directory?
      path.directory?
    end
    
    # @return [Boolean]
    def pipe?
      path.pipe?
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
        mode: stat.mode & ~(@writeable ? 0 : NonoP::PermMode[:W]),
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
end
