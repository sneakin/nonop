require 'sg/ext'
using SG::Ext

require 'sg/io/reactor'
require_relative '../decoder'

module NineP::Server
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

    def to_s
      "\#<%s %s:%s>" % [ self.class.name,
                         @io.remote_address.ip_address,
                         @io.remote_address.ip_port ]
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
      NineP::L2000::Tcreate => :on_create,
      NineP::L2000::Treaddir => :on_readdir,
      NineP::L2000::Tgetattr => :on_getattr,
      NineP::L2000::Tsetattr => :on_setattr,
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
    rescue
      $stderr.puts("Error on #{io}: #{$!.message}")
      NineP.vputs { $!.backtrace.join("\n") }
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
      # todo the  fid ties the user to the export via fid cloning
      stream = @open_fids.fetch(pkt.data.afid)
      if stream.authentic?(pkt.data.uname, pkt.data.n_uname)
        @open_fids[pkt.data.fid] = ErrantStream.instance
        reply_to(pkt, NineP::L2000::Rattach.new(aqid: environment.auth_qid))
      else
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EACCES))
      end
    rescue KeyError
      if pkt.data.afid == 0xFFFFFFFF
        on_legacy_auth(pkt)
      else
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      end
    end

    def on_legacy_auth pkt
      fs = environment.get_export(pkt.data.aname.to_s)

      if pkt.data.uname != nil || 0xFFFFFFFF == pkt.data.n_uname
        # todo auth against per export databases
        user = pkt.data.n_uname == 0xFFFFFFFF ? pkt.data.uname.to_s : pkt.data.n_uname
        NineP.vputs { "Legacy Authenticating #{user}" }
        # fixme  even safe?
        if environment.has_user?(user)
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

    # todo async reply
    def on_write pkt
      stream = @open_fids.fetch(pkt.data.fid)
      reply_to(pkt, NineP::Rwrite.new(count: stream.write(pkt.data.data, pkt.data.offset)))
    rescue KeyError
      reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
    rescue SystemCallError
      reply_to(pkt, NineP::L2000::Rerror.new($!))
    end

    # todo async reply
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
      NineP.vputs { "Opening #{pkt.data.fid} #{stream.qid.inspect}" }
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

    def on_create pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NineP.vputs { "Creating #{pkt.data.fid} #{stream.qid.inspect}" }
      begin
        stream.create(pkt.data.name, pkt.data.flags, pkt.data.mode, pkt.data.gid)
        reply_to(pkt, NineP::Rcreate.new(qid: stream.qid || stream.fs.qid,
                                         iounit: 0))
      rescue KeyError
        reply_to(pkt, NineP::L2000::Rerror.new(Errno::EBADFD))
      rescue SystemCallError
        reply_to(pkt, NineP::L2000::Rerror.new($!))
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
    }.reduce(Hash.new(NineP::L2000::DirentTypes[:UNKNOWN])) do |h, (k, v)|
      h[NineP::Qid::Types[k]] = NineP::L2000::DirentTypes[v]
      h
    end

    def map_qid_to_dirent_type qid
      QidDirentMap.fetch(qid.type)
    end

    def on_readdir pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NineP.vputs { "Reading dir #{pkt.data.fid} #{stream.inspect}" }
      ents = stream.readdir(pkt.data.count, pkt.data.offset).
        each.with_index.
        collect { NineP::L2000::Rreaddir::Dirent.new(qid: _1.qid,
                                                     offset: _2 + 1,
                                                     type: map_qid_to_dirent_type(_1.qid),
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

    def on_setattr pkt
      stream = @open_fids.fetch(pkt.data.fid)
      NineP.vputs { "Setattr #{pkt.data.fid}" }
      stats = stream.setattr(pkt.data)
      NineP.vputs { "   #{stats.inspect}" }
      reply_to(pkt, NineP::L2000::Rsetattr.new())
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
