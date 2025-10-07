require 'sg/ext'
using SG::Ext

require 'sg/io/reactor'
require_relative '../decoder'

module NonoP::Server
  class Connection
    # @return [IO]
    attr_reader :io
    # @return [Decoder]
    attr_reader :coder
    # @return [SG::IO::Reactor::Source]
    attr_reader :input
    # @return [SG::IO::Reactor::Sink]
    attr_reader :output
    # @return [Environment]
    attr_reader :environment

    # @param io [IO]
    # @param env [Environment]
    def initialize io, env
      @io = io
      @environment = env
      @coder = NonoP::L2000::Decoder.new
      @output = SG::IO::Reactor::QueuedOutput.new(@io)
      @input = SG::IO::Reactor::BasicInput.new(@io) { handle }
      @open_fids = Hash.new(ErrantStream.instance)
      env.track_connection(self)
    end

    # @return [String]
    def to_s
      "\#<%s %s:%s>" % [ self.class.name,
                         @io.remote_address.ip_address,
                         @io.remote_address.ip_port ]
    rescue SystemCallError
      super
    end

    # @return [self]
    def close
      return self if closed?
      NonoP.vputs { "Closing #{self} #{closed?}" }
      @input.close
      @output.close
      self
    ensure
      environment.untrack_connection(self)
      @closed = true
      self
    end

    # @return [Boolean]
    def closed?
      @closed
    end

    # @return [self]
    def reply_to pkt, msg
      coder.send_one(NonoP::Packet.new(tag: pkt.tag, data: msg),
                     output)
      self
    rescue SystemCallError
      NonoP.vputs { "Error sending reply: #{$!.message}" }
      close
    end

    Handlers = {
      NonoP::Tversion => :on_version,
      NonoP::L2000::Tauth => :on_auth,
      NonoP::L2000::Tattach => :on_attach,
      NonoP::Tread => :on_read,
      NonoP::Twrite => :on_write,
      NonoP::Tclunk => :on_clunk,
      NonoP::Twalk => :on_walk,
      NonoP::L2000::Topen => :on_open,
      NonoP::L2000::Tcreate => :on_create,
      NonoP::L2000::Treaddir => :on_readdir,
      NonoP::L2000::Tgetattr => :on_getattr,
      NonoP::L2000::Tsetattr => :on_setattr,
    }

    # @return [self]
    def handle
      pkt = coder.read_one(@io)
      handler = Handlers.fetch(pkt.data.class, :on_unknown)
      send(handler, pkt)
    rescue SG::PackedStruct::NoDataError, Errno::ECONNRESET
      if io.eof?
        puts("Closed #{self}")
      else
        puts("Error on #{self}: #{$!.message}")
      end
      close
    rescue
      puts("Error on #{self} #{$!.class}: #{$!.message}")
      NonoP.vputs { $!.backtrace.join("\n") }
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADMSG))
      #close
      self
    end

    # @return [void]
    def on_version pkt
      reply_to(pkt, NonoP::Rversion.new(msize: coder.max_msglen,
                                        version: NonoP::NString.new(coder.version)))
    end

    # @return [void]
    def on_auth pkt
      if environment.has_user?(pkt.data.n_uname)
        @open_fids[pkt.data.afid] = AuthStream.new(environment, pkt.data.n_uname)
        reply_to(pkt, NonoP::L2000::Rauth.new(aqid: environment.auth_qid))
      else
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EACCES))
      end
    end

    # @return [void]
    def on_attach pkt
      # todo the  fid ties the user to the export via fid cloning
      stream = @open_fids.fetch(pkt.data.afid)
      if stream.authentic?(pkt.data.uname, pkt.data.n_uname)
        @open_fids[pkt.data.fid] = ErrantStream.instance
        reply_to(pkt, NonoP::L2000::Rattach.new(aqid: environment.auth_qid))
      else
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::ENEEDAUTH))
      end
    rescue KeyError
      if pkt.data.afid == 0xFFFFFFFF
        on_legacy_auth(pkt)
      else
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
      end
    end

    # @return [void]
    def on_legacy_auth pkt
      fs = environment.get_export(pkt.data.aname.to_s)

      if pkt.data.uname != nil || 0xFFFFFFFF == pkt.data.n_uname
        # todo auth against per export databases
        user = pkt.data.n_uname == 0xFFFFFFFF ? pkt.data.uname.to_s : pkt.data.n_uname
        NonoP.vputs { "Legacy Authenticating #{user}" }
        # fixme  even safe?
        if environment.has_user?(user)
          @open_fids[pkt.data.fid] = AttachStream.new(fs, pkt.data.fid)
          reply_to(pkt, NonoP::L2000::Rattach.new(aqid: environment.auth_qid))
        else
          reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EACCES))
        end
      else
        @open_fids[pkt.data.fid] = AttachStream.new(fs, pkt.data.fid)
        reply_to(pkt, NonoP::L2000::Rattach.new(aqid: fs.qid))
      end
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::ENOENT))
    end

    # todo async reply
    # @return [void]
    def on_write pkt
      stream = @open_fids.fetch(pkt.data.fid)
      reply_to(pkt, NonoP::Rwrite.new(count: stream.write(pkt.data.data, pkt.data.offset)))
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NonoP::L2000::Rerror.new($!))
    end

    # todo async reply
    # @return [void]
    def on_read pkt
      stream = @open_fids.fetch(pkt.data.fid)
      stream.read(pkt.data.count, pkt.data.offset, &lambda do |data|
                    reply_to(pkt, NonoP::Rread.new(data: data || ''))
                  end.but!(SystemCallError) do |err| # fixme not catching
                    NonoP.vputs { "Caught #{$!}" }
                    reply_to(pkt, NonoP::L2000::Rerror.new(err))
                  end)
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NonoP::L2000::Rerror.new($!))      
    end

    # @return [void]
    def on_clunk pkt
      if stream = @open_fids.delete(pkt.data.fid)
        stream.close
        reply_to(pkt, NonoP::Rclunk.new)
      else
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
      end
    end

    # @return [void]
    def on_walk pkt
      # Empty list needs to make a new fid
      stream = @open_fids.fetch(pkt.data.fid)
      qids, fsid = stream.walk(pkt.data.wnames.collect(&:to_s))
      NonoP.vputs { "Walked #{fsid} #{pkt.data.wnames} #{qids.inspect}" }
      if qids && fsid
        new_stream = FileStream.new(stream.fs, pkt.data.newfid, qids, fsid)
        @open_fids[pkt.data.newfid] = new_stream
        reply_to(pkt, NonoP::Rwalk.new(wqid: qids))
      else
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::ENOENT))
      end
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NonoP::L2000::Rerror.new($!))
    end

    # @return [void]
    def on_open pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NonoP.vputs { "Opening #{pkt.data.fid} #{stream.class} #{stream.qid.inspect}" }
      begin
        stream.open(NonoP::OpenFlags.new(pkt.data.flags))
        reply_to(pkt, NonoP::Ropen.new(qid: stream.qid || stream.fs.qid,
                                       iounit: 0))
      rescue KeyError
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NonoP::L2000::Rerror.new($!))
        NonoP.vputs { [ "Error: #{$!.message}", *$!.backtrace ] }
      end
    end

    # @return [void]
    def on_create pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NonoP.vputs { "Creating #{pkt.data.fid} #{stream.qid.inspect}" }
      begin
        stream.create(pkt.data.name.to_s,
                      NonoP::OpenFlags.new(pkt.data.flags),
                      NonoP::PermMode.new(pkt.data.mode),
                      pkt.data.gid)
        reply_to(pkt, NonoP::Rcreate.new(qid: stream.qid || stream.fs.qid,
                                         iounit: 0))
      rescue KeyError
        reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NonoP::L2000::Rerror.new($!))
        NonoP.vputs { [$!.to_s, *$!.backtrace ] }
      end
    end

    QidDirentMap = {
      DIR: :DIR,
      APPEND: :REG,
      EXCL: :REG,
      MOUNT: :DIR,
      AUTH: :FIFO,
      TMP: :REG,
      SYMLINK: :LNK,
      LINK: :LNK,
      FILE: :REG,
    }.reduce(Hash.new(NonoP::L2000::DirentTypes[:UNKNOWN])) do |h, (k, v)|
      h[NonoP::Qid::Types[k]] = NonoP::L2000::DirentTypes[v]
      h
    end

    # @param qid [Qid]
    # @return [Integer]
    def map_qid_to_dirent_type qid
      QidDirentMap.fetch(qid.type)
    end

    # @return [void]
    def on_readdir pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NonoP.vputs { "Reading dir #{pkt.data.fid}" }
      ents = stream.readdir(pkt.data.count, pkt.data.offset).
        each.with_index.
        collect { NonoP::L2000::Rreaddir::Dirent.new(qid: _1.qid,
                                                     offset: _2 + 1,
                                                     type: map_qid_to_dirent_type(_1.qid),
                                                     name: NonoP::NString.new(_1.name)) }
      reply_to(pkt, NonoP::L2000::Rreaddir.new(entries: ents))
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NonoP::L2000::Rerror.new($!))
    end

    # @return [void]
    def on_getattr pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NonoP.vputs { "Getattr #{pkt.data.fid}" }
      stats = stream.getattr(pkt.data.request_mask)
      NonoP.vputs { "   => #{stats.inspect}" }
      reply_to(pkt, NonoP::L2000::Rgetattr.new(**stats))
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NonoP::L2000::Rerror.new($!))
    end

    # @return [void]
    def on_setattr pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NonoP.vputs { "Setattr #{pkt.data.fid}" }
      stats = stream.setattr(pkt.data)
      NonoP.vputs { "   #{stats.inspect}" }
      reply_to(pkt, NonoP::L2000::Rsetattr.new())
    rescue KeyError
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NonoP::L2000::Rerror.new($!))
    end

    # @return [void]
    def on_unknown pkt
      reply_to(pkt, NonoP::L2000::Rerror.new(Errno::ENOTSUP))
    end
  end
end
