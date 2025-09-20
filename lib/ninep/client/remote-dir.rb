require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'
require_relative '../remote-path'

module NineP
  class RemoteDir
    READ_SIZE = 4096
    
    attr_reader :path, :attachment, :flags, :fid
    
    def initialize path, attachment:, flags: nil, fid: nil, &blk
      @path = RemotePath.new(path)
      @attachment = attachment
      @flags = flags || NineP::L2000::Topen::Flags[:DIRECTORY]
      @fid = fid || client.next_fid
      attachment.walk(@path, nfid: @fid) do |pkt|
        case pkt
        when Rwalk then
          if pkt.nwqid < @path.size
            blk&.call(WalkError.new(2, @path.parent(pkt.nwqid, from_top: true)))
          else
            client.request(NineP::L2000::Topen.new(fid: @fid,
                                                   flags: @flags)) do |pkt|
              @ready = true
              blk&.call(self)
            end
          end
        when StandardError then blk&.call(pkt)
        else blk&.call(TypeError.new(pkt.class))
        end
      end
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
      client.clunk(fid)
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
      client.request(NineP::L2000::Treaddir.new(fid: fid,
                                                offset: offset,
                                                count: count),
                     wait_for: wait_for) do |result|
        blk.call(NineP.maybe_wrap_error(result, ReadError))
      end
    end
  end
end
