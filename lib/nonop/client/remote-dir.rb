require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'
require_relative '../remote-path'

module NonoP
  class RemoteDir
    READ_SIZE = 4096

    attr_reader :path, :attachment, :flags, :fid

    def initialize path, attachment:, flags: nil, fid: nil, &blk
      @path = RemotePath.new(path)
      @attachment = attachment
      @flags = NonoP::L2000::Topen::FlagField.new(flags || :DIRECTORY)
      @fid = fid || client.next_fid
      open_self(&blk)
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
    def entries count: nil, offset: nil, wait_for: true, &blk
      return to_enum(__method__, count:, offset:, wait_for: true) unless blk

      count ||= READ_SIZE

      Async.reduce(0.upto(MAX_U64), offset || 0) do |n, offset, &cc|
        readdir(count, offset, wait_for: wait_for) do |dir|
          if StandardError === dir
            cc.call(dir, offset)
          else
            dir.entries.each(&blk)
            cc.call(dir.entries.size < count, offset + dir.entries.size)
          end
        end
      end
    end

    def readdir count, offset = 0, wait_for: nil, &blk
      client.request(NonoP::L2000::Treaddir.new(fid: fid,
                                                offset: offset,
                                                count: count),
                     wait_for: wait_for) do |result|
        blk.call(NonoP.maybe_wrap_error(result, ReadError))
      end
    end

    def mkdir path, mode: nil, gid: nil, &blk
      result = client.request(NonoP::L2000::Tmkdir.
                              new(dfid: fid,
                                  name: NString.new(path.to_str),
                                  mode: mode || 0755, \
                                  gid: gid || Process.gid),
                              wait_for: blk == nil) do |pkt|
        blk&.call(NonoP.maybe_wrap_error(pkt, MkdirError))
      end
      if blk
        self
      else
        NonoP.maybe_wrap_error(result.data, MkdirError)
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
            blk.call(WalkError.new(2, @path.parent(pkt.nwqid + 1, from_top: true)))
          else
            blk.call(pkt)
          end
        when StandardError then blk.call(pkt)
        else blk.call(TypeError.new(pkt.class))
        end
      end
    end

    def open_self &blk
      return blk.call(self) if ready?

      walk_to_self do |pkt|
        case pkt
        when Rwalk then
          client.request(NonoP::L2000::Topen.new(fid: @fid,
                                                 flags: @flags)) do |pkt|
            if ErrorPayload === pkt
              blk.call(NonoP.maybe_wrap_error(pkt, OpenError))
            else
              client.track_fid(@fid) { self.close }
              @ready = true
              blk.call(self)
            end
          end
        when StandardError then blk.call(pkt)
        else blk.call(TypeError.new(pkt.class))
        end
      end
    end
  end
end
