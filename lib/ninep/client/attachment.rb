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
      RemoteFile.new(*a, **o.merge(parent_fid: fid, client: client), &blk)
    end

    def opendir path
    end
  end
end
