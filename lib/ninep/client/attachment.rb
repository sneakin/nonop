require 'sg/ext'
using SG::Ext

require_relative 'remote-file'
require_relative 'remote-dir'

module NineP
  class Attachment
    attr_reader :qid, :client
    attr_reader :fid, :afid, :uname, :n_uname, :aname

    def initialize client:, fid: nil, afid: nil, uname: nil, n_uname: nil, aname:, &blk
      @client = client
      @fid = fid || 0
      @afid = afid || -1
      @uname = uname || ''
      @n_uname = n_uname || -1
      @aname = aname
      client.request(NineP::L2000::
                     Tattach.new(fid: @fid,
                                 afid: @afid,
                                 uname: NineP::NString.new(uname),
                                 aname: NineP::NString.new(aname),
                                 n_uname: n_uname)) do |pkt|
        case pkt
        when ErrorPayload then raise AttachError.new(pkt)
        when Rattach then
          client.track_fid(@fid)
          @qid = pkt.aqid
          @ready = true
          blk&.call(self)
        end
      end
    end

    def ready?
      @ready
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
      result = nil
      walk(path, nfid: nfid, wait_for: blk == nil) do |walk|
        if ErrorPayload === walk
          err = NineP.maybe_wrap_error(walk, WalkError)
          blk&.call(err)
          return err
        else
          result = client.request(NineP::L2000::Tgetattr.new(fid: nfid),
                                  wait_for: blk == nil) do |pkt|
            client.clunk(nfid)
            blk&.call(NineP.maybe_wrap_error(pkt, GetAttrError))
          end
        end
      end

      if blk
        self
      else
        NineP.maybe_wrap_error(result.data, GetAttrError)
      end
    end

    def walk path, nfid: nil, wait_for: nil, &blk
      nfid ||= client.next_fid
      path = RemotePath.new(path)
      result = client.request(NineP::Twalk.new(fid: fid,
                                               newfid: nfid,
                                               wnames: path.collect { NineP::NString.new(_1) }),
                              wait_for: wait_for) do |pkt|
        case pkt
        when Rwalk then
          client.track_fid(nfid)
          blk&.call(pkt)
        when ErrorPayload then
          err = WalkError.new(pkt, path)
          blk&.call(err)
          return err if wait_for
        else err = TypeError.new(pkt.class)
          blk&.call(err)
          return err if wait_for
        end
      end

      if blk
        self
      else
        result
      end
    end
  end

end
