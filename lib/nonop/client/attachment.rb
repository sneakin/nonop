require 'sg/ext'
using SG::Ext

require_relative 'remote-file'
require_relative 'remote-dir'

module NonoP
  class Attachment
    attr_reader :qid, :client
    attr_reader :fid, :afid, :uname, :n_uname, :aname

    def initialize client:, fid: nil, afid: nil, uname: nil, n_uname: nil, aname:, wait_for: false, &blk
      @client = client
      @fid = fid || client.next_fid
      @afid = afid || -1
      @uname = uname || ''
      @n_uname = n_uname || -1
      @aname = aname
      client.request(NonoP::L2000::
                     Tattach.new(fid: @fid,
                                 afid: @afid,
                                 uname: NonoP::NString.new(uname),
                                 aname: NonoP::NString.new(aname),
                                 n_uname: n_uname),
                     wait_for: wait_for || blk == nil) do |pkt|
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

    def close wait_for: false, &blk
      @ready = false
      client.clunk(@fid, wait_for:, &blk)
      self
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
      walk(path, fid: fid, nfid: nfid, wait_for: blk == nil) do |walk|
        if StandardError === walk
          return NonoP.maybe_call(blk, walk)
        else
           result = client.request(NonoP::L2000::Tgetattr.new(fid: nfid),
                                  wait_for: blk == nil) do |pkt|
            client.clunk(nfid)
            blk&.call(NonoP.maybe_wrap_error(pkt, GetAttrError))
          end
        end
      end

      blk ? self : result.data
    end

    def stat(path, fid: nil, &blk)
      nfid ||= client.next_fid
      result = nil
      walk(path, fid: fid, nfid: nfid, wait_for: blk == nil) do |walk|
        if StandardError === walk
          return NonoP.maybe_call(blk, walk)
        else
          result = client.request(NonoP::Tstat.new(fid: nfid),
                                  wait_for: blk == nil) do |pkt|
            client.clunk(nfid)
            blk&.call(NonoP.maybe_wrap_error(pkt, StatError))
          end
        end
      end

      blk ? self : result.data
    end

    def walk path, nfid: nil, fid: nil, wait_for: nil, &blk
      nfid ||= client.next_fid
      path = RemotePath.new(path) unless RemotePath === path
      result = client.request(NonoP::Twalk.new(fid: fid || self.fid,
                                               newfid: nfid,
                                               wnames: path.collect { NonoP::NString.new(_1) }),
                              wait_for: wait_for || blk == nil) do |pkt|
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

      blk ? self : result.data
    end
  end

end
