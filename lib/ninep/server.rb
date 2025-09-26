require 'sg/ext'
using SG::Ext

require 'ninep'

module NineP
  module Server
    class FileSystem
      def initialize
        @fids = {}
      end
      
      def qid
        @qid ||= NineP::Qid.new(type: NineP::Qid::Types[:MOUNT], version: 0, path: '/')
      end

      def close fid
        f = @fids.delete(fid)
        f&.call
        self
      end
      
      def walk path
        NineP.vputs { "Walking to #{path}" }
        if path.size == 0
          [ qid, 0 ]
        else
          false
        end
      end

      # todo stub api
    end

    module PermMode
      PERMS = 0777
      DIR = 040000
      FILE = 0100000
    end
    
    class HashFileSystem
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
          
          delegate :truncate, :read, :write, to: :data

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

        def type
          0
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
        
        delegate :truncate, :read, :write, to: :backend
        delegate :size, :getattr, to: :entry
      end
      
      def initialize entries: nil, umask: nil
        @entries = Hash[(entries || {}).collect { |name, data|
                          [ name,
                            case data
                            when Entry then data
                            when String then BufferEntry.new(name, data, umask: umask)
                            when Pathname then FileEntry.new(name, path: data, umask: umask)
                            else StaticEntry.new(name, data, umask: umask)
                            end
                          ]}]
        @next_id = 0
        @fsids = {}
      end
      
      def qid
        @qid ||= NineP::Qid.new(type: NineP::Qid::Types[:MOUNT], version: 0, path: '/')
      end

      def qid_for path
        @entries.fetch(path).qid
      end

      def open fsid, flags
        NineP.vputs { "Opening #{fsid} #{@fsids[fsid]}" }
        return self if fsid == 0

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
        fsid == 0 ? '/' : @fsids.fetch(fsid).path
      end
      
      def walk path, old_fsid = nil
        NineP.vputs { "Walking to #{path} #{old_fsid}" }
        if path.size == 0
          if old_fsid == 0
            [ [], 0 ]
          else
            i = next_id
            @fsids[i] = case old_fsid
                        when nil then FSID.new(path.last, @entries.fetch(path.last))
                        else @fsids.fetch(old_fsid).dup
                        end
            [ [], i ]
          end
        elsif path.size == 1
          i = next_id
          entry = @entries.fetch(path.last)
          @fsids[i] = FSID.new(path.last, entry)
          if entry
            [ [ entry.qid ], i ]
          else
            false
          end
        else
          false
        end
      end

      def readdir fsid, count, offset = 0
        case fsid
        when 0 then
          @entries.values[offset, count] || []
        else raise Errno::EBADFD
        end
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
        if fsid == 0
          DEFAULT_DIR_ATTRS.
            merge(qid: qid,
                  size: @entries.size,
                  mode: PermMode::DIR | MODE_EXECUTABLE,
                  blocks: @entries.size / BLOCK_SIZE)
        else
          @entries.fetch(@fsids.fetch(fsid).path).getattr
        end
      rescue KeyError
        raise Errno::ENOENT
      end
    end

    class AuthService
      def auth user, creds
        false
      end
      def find_user user
        nil
      end
      def has_user? user
        false
      end
      def user_count
        0
      end
    end

    class AuthHash < AuthService
      def initialize db
        @db = db
      end
      def auth user, creds
        u = find_user(user)
        u && u[1] == creds.strip
      end
      def find_user user
        case user
        when String then @db[user]
        when Integer then @db.find { _2[0] == user }&.then { _2 }
        else raise TypeError.new('User not a string or ID.')
        end
      end
      def has_user? user
        find_user(user) != nil
      end
      def user_count
        @db.size
      end
    end

    class YesAuth < AuthHash
      def auth user, creds
        return false unless has_user?(user)
        true
      end
    end

    class MungeAuth < AuthHash
      def auth user, creds
        return false unless has_user?(user)
        status, meta, payload = Munge.verify do |io|
          io.puts(creds)
        end
        status == 0 && meta.fetch('STATUS', '') =~ /^Success/ &&
          (Integer === user && meta.fetch('UID', '') =~ /\(#{user}\)/ ||
           String === user && meta.fetch('UID', '') =~ /#{user}/)
      end
    end

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
    
    class ErrantStream < Stream
      include Singleton
    end

    class AuthStream < Stream
      def initialize environment, user, data = nil
        @environment = environment
        @user = user
        @data = data || ''
      end

      def write data, offset = 0
        raise EOFError.new if closed?
        @data[offset, data.size] = data
        data.size
      end

      def authentic? uname, uid
        NineP.vputs { [ "Authenticating #{@user}", @data.inspect, @environment.find_user(@user).inspect ] }
        (@user == uname || @user == uid) && @environment.auth(@user, @data)
      end

      def dup
        self.class.new(environment, user, data)
      end
    end

    class FileStream < Stream
      attr_reader :fs, :fid, :qids, :fsid
      
      def initialize fs, fid, qids, fsid
        @fs = fs
        @fid = fid
        @qids = qids
        @fsid = fsid
      end

      def dup
        self.class.new(fs, fid, qids, fsid)
      end

      def qid
        @qid ||= @qids[-1] || NineP::Qid.new(type: NineP::Qid::Types[:FILE], version: 0, path: @fs.fsid_path(@fsid)[0, 8])
      end

      def close
        @fs.close(@fsid)
      end

      def open flags
        @fs.open(@fsid, flags)
      end
      
      def readdir count, offset = 0
        @fs.readdir(@fsid, count, offset)
      end

      def read count, offset = 0
        @fs.read(@fsid, count, offset)
      end

      def write data, offset = 0
        @fs.write(@fsid, data, offset)
      end

      def walk path
        @fs.walk(path, @fsid)
      end

      def getattr mask
        @fs.getattr(@fsid)
      end
    end
      
    class AttachStream < Stream
      attr_reader :fs
      
      def initialize fs, fid
        @fs = fs
        @fid = fid
      end

      def dup
        self.class.new(fs, fid)
      end

      def close
        self
      end

      def walk path
        @fs.walk(path, 0)
      end

      def getattr mask
        @fs.getattr(0)
      end
    end
      
    class Environment
      attr_reader :authsrv, :auth_qid
      attr_reader :exports, :connections
      
      def initialize authsrv: nil
        @authsrv = authsrv
        @exports = {}
        @auth_qid = NineP::Qid.new(type: NineP::Qid::Types[:AUTH], version: 0, path: '')
        @started_at = Time.now
        @connections = {}
      end

      def export name, fs
        @exports[name] = fs
        self
      end

      def get_export name
        @exports.fetch(name)
      end

      delegate :auth, :find_user, :has_user?, to: :authsrv

      def track_connection conn
        @connections[conn] = conn
        self
      end

      def untrack_connection conn
        @connections.delete(conn)
        self
      end
      
      def stats
        { exports: exports.size,
          connections: connections.size,
          users: authsrv.user_count,
          now: Time.now,
          uptime: Time.now - @started_at,
          started_at: @started_at
        }
      end

      def done! &cc
        @connections.values.each(&:close)
        cc.call
      end
    end
    
    class Connection
      attr_reader :io, :coder, :input, :output, :environment
      
      def initialize io, env
        @io = io
        @environment = env
        @coder = NineP::L2000::Decoder.new
        @output = SG::IO::Reactor::QueuedOutput.new(@io)
        @input = SG::IO::Reactor::BasicInput.new(@io) { handle }
        @open_fids = Hash.new(ErrantStream.instance)
        env.track_connection(self)
      end

      def close
        return if closed?
        NineP.vputs { "Closing #{self}" }
        @output.close
        @io.close
        environment.untrack_connection(self)
        @closed = true
        self
      end

      def closed?
        @closed
      end

      def reply_to pkt, msg
        coder.send_one(NineP::Packet.new(tag: pkt.tag, data: msg),
                       output)
      rescue SystemCallError
        NineP.vputs { "Error sending reply: #{$!.message}" }
        close
      end

      Handlers = {
        NineP::Tversion => :on_version,
        NineP::L2000::Tauth => :on_auth,
        NineP::L2000::Tattach => :on_attach,
        NineP::Tread => :on_read,
        NineP::Twrite => :on_write,
        NineP::Tclunk => :on_clunk,
        NineP::Twalk => :on_walk,
        NineP::L2000::Topen => :on_open,
        NineP::L2000::Treaddir => :on_readdir,
        NineP::L2000::Tgetattr => :on_getattr,
      }
      
      def handle
        pkt = coder.read_one(@io)
        handler = Handlers.fetch(pkt.data.class, :on_unknown)
        send(handler, pkt)
      rescue SG::PackedStruct::NoDataError, Errno::ECONNRESET
        if io.eof?
          puts("Closed #{io}")
        else
          $stderr.puts("Error on #{io}: #{$!.message}")
        end
        close
      rescue NineP::Error
        $stderr.puts("Error on #{io}: #{$!.message}")
        reply_to(pkt, NineP::L2000::Rerror.new($!))
        close
      end

      def on_version pkt
        reply_to(pkt, NineP::Rversion.new(msize: coder.max_msglen,
                                          version: NineP::NString.new(coder.version)))
      end

      def on_auth pkt
        if environment.has_user?(pkt.data.n_uname)
          @open_fids[pkt.data.afid] = AuthStream.new(environment, pkt.data.n_uname)
          reply_to(pkt, NineP::L2000::Rauth.new(aqid: environment.auth_qid))
        else
          reply_to(pkt, NineP::L2000::Rerror.new(Errno::EACCES))
        end
      end

      def on_attach pkt
        stream = @open_fids.fetch(pkt.data.afid)
        if stream.authentic?(pkt.data.uname, pkt.data.n_uname)
          @open_fids[pkt.data.fid] = ErrantStream.instance
          reply_to(pkt, NineP::L2000::Rattach.new(aqid: environment.auth_qid))
        else
          reply_to(pkt, NineP::L2000::Rerror.new(Errno::EACCES))
        end
      rescue KeyError
        if pkt.data.afid == 0xFFFFFFFF
          begin
            fs = environment.get_export(pkt.data.aname.to_s)

            if pkt.data.uname != nil || 0xFFFFFFFF == pkt.data.n_uname
              # todo auth against per export databases
              user = pkt.data.n_uname == 0xFFFFFFFF ? pkt.data.uname.to_s : pkt.data.n_uname
              NineP.vputs { "Authenticating #{user}" }
              if environment.auth(user, nil)
                @open_fids[pkt.data.fid] = AttachStream.new(fs, pkt.data.fid)
                reply_to(pkt, NineP::L2000::Rattach.new(aqid: environment.auth_qid))
              else
                reply_to(pkt, NineP::L2000::Rerror.new(Errno::EACCES))
              end
            else
              @open_fids[pkt.data.fid] = AttachStream.new(fs, pkt.data.fid)
              reply_to(pkt, NineP::L2000::Rattach.new(aqid: fs.qid))
            end
          rescue KeyError
            reply_to(pkt, NineP::L2000::Rerror.new(Errno::ENOENT))
          end
        else
          reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
        end
      end

      def on_write pkt
        stream = @open_fids.fetch(pkt.data.fid)
        reply_to(pkt, NineP::Rwrite.new(count: stream.write(pkt.data.data, pkt.data.offset)))
      rescue KeyError
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NineP::L2000::Rerror.new($!))
      end

      def on_read pkt
        stream = @open_fids.fetch(pkt.data.fid)
        reply_to(pkt, NineP::Rread.new(data: stream.read(pkt.data.count, pkt.data.offset) || ''))
      rescue KeyError
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NineP::L2000::Rerror.new($!))
      end

      def on_clunk pkt
        if stream = @open_fids.delete(pkt.data.fid)
          stream.close
          reply_to(pkt, NineP::Rclunk.new)
        else
          reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
        end
      end

      def on_walk pkt
        # Empty list needs to make a new fid
        stream = @open_fids.fetch(pkt.data.fid)
        qids, fsid = stream.walk(pkt.data.wnames.collect(&:to_s))
        NineP.vputs { "Walked #{pkt.data.wnames} #{qids.inspect}" }
        if qids && fsid
          new_stream = FileStream.new(stream.fs, pkt.data.newfid, qids, fsid)
          @open_fids[pkt.data.newfid] = new_stream
          reply_to(pkt, NineP::Rwalk.new(wqid: qids))
        else
          reply_to(pkt, NineP::L2000::Rerror.new(Errno::ENOENT))
        end
      rescue KeyError
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NineP::L2000::Rerror.new($!))
      end

      def on_open pkt
        stream = @open_fids.fetch(pkt.data.fid)
        NineP.vputs { "Opening #{pkt.data.fid} #{stream.qid.inspect} #{stream.inspect}" }
        begin
          stream.open(pkt.data.flags)
          reply_to(pkt, NineP::Ropen.new(qid: stream.qid || stream.fs.qid,
                                         iounit: 0))
        rescue KeyError
          reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
        rescue SystemCallError
          reply_to(pkt, NineP::L2000::Rerror.new($!))
        end
      end

      def on_readdir pkt
        stream = @open_fids.fetch(pkt.data.fid)
        NineP.vputs { "Reading dir #{pkt.data.fid} #{stream.inspect}" }
        ents = stream.readdir(pkt.data.count, pkt.data.offset).
          each.with_index.
          collect { NineP::L2000::Rreaddir::Dirent.new(qid: _1.qid,
                                                       offset: _2 + 1,
                                                       type: _1.type,
                                                       name: NineP::NString.new(_1.name)) }
        reply_to(pkt, NineP::L2000::Rreaddir.new(entries: ents))
      rescue KeyError
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NineP::L2000::Rerror.new($!))
      end

      def on_getattr pkt
        stream = @open_fids.fetch(pkt.data.fid)
        NineP.vputs { "Getattr #{pkt.data.fid}" }
        stats = stream.getattr(pkt.data.request_mask)
        NineP.vputs { "   #{stats.inspect}" }
        reply_to(pkt, NineP::L2000::Rgetattr.new(**stats))
      rescue KeyError
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NineP::L2000::Rerror.new($!))
      end

      def on_unknown pkt
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::ENOTSUP))
      end
    end
  end
end
