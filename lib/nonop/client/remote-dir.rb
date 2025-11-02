require 'sg/ext'
using SG::Ext

require_relative '../constants'
require_relative '../async'
require_relative '../util'
require_relative '../remote-path'
require_relative '../open-flags'

module NonoP
  class RemoteDir
    READ_SIZE = 4096

    attr_reader :path, :attachment, :flags, :fid

    def initialize path, attachment:, flags: nil, fid: nil, &blk
      @path = RemotePath.new(path)
      @attachment = attachment
      @flags = NonoP::OpenFlags.new(flags || :DIRECTORY)
      @fid = fid || client.next_fid
      open_self(&blk).wait # todo ready like RemoteFile
    end

    def client
      attachment.client
    end

    def parent_fid
      attachment.fid
    end

    def ready?
      @ready
    end

    def close
      client.clunk(fid) do |reply|
        raise reply if StandardError === reply
        @fid = nil
      end
      @ready = false
      self
    end

    # todo an async version to complement an enumerable; needs to pass a continuation to ~blk~
    def entries count: nil, offset: nil, &blk
      return to_enum(__method__, count:, offset:) unless blk

      read_size = count || READ_SIZE
      count ||= NonoP::MAX_U64
      
      Async.reduce(0.upto(count), offset || 0) do |n, offset, &cc| 
        readdir(read_size, offset) do |dir|
          if StandardError === dir
            cc.call(dir, offset)
          else
            dir.entries.each(&blk)
            noff = offset + dir.entries.size
            cc.call(dir.entries.size < read_size || noff >= count, noff)
          end
        end.wait
      end
    end

    def readdir count = nil, offset = nil, &blk
      client.request(NonoP::L2000::Treaddir.new(fid: fid,
                                                offset: offset || 0,
                                                count: count || READ_SIZE)) do |result|
        NonoP.maybe_call(blk, NonoP.maybe_wrap_error(result, ReadError))
      end
    end

    def mkdir path, mode: nil, gid: nil, &blk
      client.request(NonoP::L2000::Tmkdir.
                     new(dfid: fid,
                         name: NString.new(path.to_str),
                         mode: mode || 0755,
                         gid: gid || Process.gid)) do |pkt|
        NonoP.maybe_call(blk, NonoP.maybe_wrap_error(pkt, MkdirError))
      end
    end

    def getattr entry, &blk
      attachment.getattr(entry, fid: fid, &blk)
    end

    def stat entry, &blk
      attachment.stat(entry, &blk)
    end

    def walk_to_self &blk
      attachment.walk(@path, nfid: @fid) do |pkt|
        case pkt
        when Rwalk then
          if pkt.nwqid < @path.size
            NonoP.maybe_call(blk, WalkError.new(2, @path.parent(pkt.nwqid + 1, from_top: true)))
          else
            NonoP.maybe_call(blk, pkt)
          end
        else raise TypeError.new(pkt.class)
        end
      end
    end

    def open_self &blk
      return NonoP.maybe_call(blk, self) if ready?

      walk_to_self do |pkt|
        case pkt
        when Rwalk then
          client.request(NonoP::L2000::Topen.new(fid: @fid, flags: @flags)) do |pkt|
            if ErrorPayload === pkt
              NonoP.maybe_call(blk, NonoP.maybe_wrap_error(pkt, OpenError))
            else
              client.track_fid(@fid) { self.close }
              @ready = true
              NonoP.maybe_call(blk, self)
            end
          end
        else raise TypeError.new(pkt.class)
        end
      end
    end
  end
end
