require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'
require_relative '../remote-path'
require_relative 'remote-io'

module NineP
  class RemoteFile
    attr_reader :attachment, :path, :flags, :io
    
    def initialize path, attachment:, flags: nil, fid: nil, mode: nil, gid: nil, &blk
      @path = RemotePath.new(path)
      @attachment = attachment
      @flags = L2000::Topen.flag_mask(flags || [:RDONLY])
      @fid = fid || client.next_fid
      @io = RemoteIO.new(client, @fid)

      open(mode: mode, gid: gid, &blk)
    end

    def client
      attachment.client
    end

    def parent_fid
      attachment.fid
    end

    def open mode: nil, gid: nil, &blk
      attachment.walk(@path, nfid: @fid) do |pkt|
        case pkt
        when Rwalk then
          if pkt.nwqid < @path.size
            blk&.call(WalkError.new(2, @path.parent(pkt.nwqid, from_top: true)))
          else
            client.track_fid(@fid) do
              close
            end
            client.request(NineP::L2000::Topen.new(fid: @fid,
                                                   flags: @flags)) do |pkt|
              if ErrorPayload === pkt
                blk&.call(OpenError.new(pkt))
              else
                @ready = true
                blk&.call(self)
              end
            end
          end
        when StandardError then
          if 0 != (@flags & NineP::L2000::Topen::Flags[:CREATE])
            create(mode: mode, gid: gid, &blk)
          else
            blk&.call(pkt)
          end
        else blk&.call(TypeError.new(pkt))
        end
      end
    end

    def ready?
      @ready
    end

    def create mode: nil, gid: nil, &blk
      attachment.walk([], nfid: @fid) do |pkt|
        case pkt
        when Rwalk then
          client.request(L2000::Tcreate.new(fid: @fid,
                                            name: NString.new(@path.basename),
                                            flags: @flags,
                                            mode: mode || 0644,
                                            gid: gid || 0)) do |pkt|
            case pkt
            when ErrorPayload then blk&.call(CreateError.new(pkt, path))
            else blk&.call(self)
            end
          end
        when ErrorPayload then blk&.call(WalkError.new(pkt, path))
        else raise TypeError.new(pkt)
        end
      end
    end
    
    def close &blk
      @io.close(&blk)
      @ready = false
      self
    end

    # todo length limited to msglen
    # todo handling multiple replies for big reads
    def read length, offset: 0, &blk
      r = @io.read(length, offset:, &blk)
      @io == r ? self : r
    end

    def write data, offset: 0, length: nil, &blk
      r = @io.write(data, offset:, length:, &blk)
      @io == r ? self : r
    end
    
    def write_one data, offset: 0, &blk
      r = @io.write_one(data, offset:, &blk)
      @io == r ? self : r
    end
    
    def wrap_error_or_data pkt, error = Error
      case pkt
      when ErrorPayload then error.new(pkt, path)
      else pkt.data
      end
    end
  end
end
