require 'sg/ext'
using SG::Ext

require_relative 'remote-file'
require_relative 'remote-dir'

module NonoP
  class Attachment
    attr_reader :qid, :client
    attr_reader :fid, :afid, :uname, :n_uname, :aname

    def initialize client:, fid: nil, afid: nil, uname: nil, n_uname: nil, aname:, &blk
      @client = client
      @fid = fid || client.next_fid
      @afid = afid || -1
      @uname = uname || ''
      @n_uname = n_uname || -1
      @aname = aname
      @attach_req = client.request(NonoP::L2000::
                     Tattach.new(fid: @fid,
                                 afid: @afid,
                                 uname: NonoP::NString.new(uname),
                                 aname: NonoP::NString.new(aname),
                                 n_uname: n_uname)) do |pkt|
        case pkt
        when ErrorPayload then raise (@afid == 0xFFFFFFFF ? AuthError : AttachError).new(pkt)
        when Rattach then
          client.track_fid(@fid)
          @qid = pkt.aqid
          @ready = true
          blk&.call(self)
        end
      end
    end

    def wait
      @attach_req.wait
      self
    end
    
    def ready?
      @ready
    end

    def close &blk
      @ready = false
      client.clunk(@fid, &blk)
    end

    def open *a, **o, &blk
      raise NotReady unless ready?
      RemoteFile.new(*a, **o.merge(attachment: self), &blk)
    end

    def opendir *a, **o, &blk
      raise NotReady unless ready?
      RemoteDir.new(*a, **o.merge(attachment: self), &blk)
    end

    def getattr(path, fid: nil, &blk)
      nfid ||= client.next_fid
      walk(path, fid: fid, nfid: nfid) do |walk|
        if StandardError === walk
          return NonoP.maybe_call(blk, walk)
        else
          client.request(NonoP::L2000::Tgetattr.new(fid: nfid)) do |pkt|
            client.clunk(nfid)
            NonoP.maybe_call(blk, NonoP.maybe_wrap_error(pkt, GetAttrError))
          end.skip_unless(blk == nil).wait
        end
      end.skip_unless(blk == nil).wait
    end

    def stat(path, fid: nil, &blk)
      nfid ||= client.next_fid
      walk(path, fid: fid, nfid: nfid) do |walk|
        if StandardError === walk
          return NonoP.maybe_call(blk, walk)
        else
          client.request(NonoP::Tstat.new(fid: nfid)) do |pkt|
            client.clunk(nfid)
            blk&.call(NonoP.maybe_wrap_error(pkt, StatError))
          end.skip_unless(blk == nil).wait
        end
      end.skip_unless(blk == nil).wait
    end

    def walk path, nfid: nil, fid: nil, &blk
      nfid ||= client.next_fid
      path = RemotePath.new(path) unless RemotePath === path
      client.request(NonoP::Twalk.new(fid: fid || self.fid,
                                      newfid: nfid,
                                      wnames: path.collect { NonoP::NString.new(_1) })) do |pkt|
        case pkt
        when Rwalk then
          client.track_fid(nfid)
          NonoP.maybe_call(blk, pkt)
        when ErrorPayload then
          next NonoP.maybe_call(blk, WalkError.new(pkt, path))
        else
          next NonoP.maybe_call(blk, TypeError.new(pkt.class))
        end
      end
    end
  end

end
