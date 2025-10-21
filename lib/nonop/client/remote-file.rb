require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'
require_relative '../remote-path'
require_relative 'remote-io'
require_relative '../open-flags'

module NonoP
  class RemoteFile
    attr_reader :attachment, :path, :flags, :io

    def initialize path, attachment:, flags: nil, fid: nil, mode: nil, gid: nil, &blk
      @path = RemotePath.new(path)
      @attachment = attachment
      @flags = NonoP::OpenFlags.new(flags || :RDONLY)
      @fid = fid || client.next_fid
      @io = RemoteIO.new(client, @fid, path)
      @open_req = open(mode: mode, gid: gid, &blk)
    end

    def client
      attachment.client
    end

    def parent_fid
      attachment.fid
    end

    def open mode: nil, gid: nil, &blk
      attachment.walk(@path, nfid: @fid) do |pkt|
        NonoP.vputs { "Walked to #{@path} #{@flags} #{@flags & :CREATE} #{@path.size} #{pkt.inspect}" }
        case pkt
        when Rwalk then
          if pkt.nwqid < @path.size
            client.clunk(@fid) do 
              if @flags & :CREATE
                create(mode: mode, gid: gid, &blk).wait
              else
                NonoP.maybe_call(blk, WalkError.new(2, @path.parent(pkt.nwqid, from_top: true)))
              end
            end.wait
          else
            client.track_fid(@fid) { self.close }
            client.request(NonoP::L2000::Topen.new(fid: @fid,
                                                   flags: @flags)) do |pkt|
              if ErrorPayload === pkt
                NonoP.maybe_call(blk, OpenError.new(pkt))
              else
                @ready = true
                NonoP.maybe_call(blk, self)
              end
            end.wait
          end
        when Error then blk ? blk.call(pkt) : raise(pkt)
        else blk ? blk.call(TypeError.new(pkt)) : raise(TypeError.new(pkt.class.to_s))
        end
      end
    end

    def wait
      @open_req.wait
      self
    end
    
    def ready?
      @ready
    end

    def create mode: nil, gid: nil, &blk
      attachment.walk(@path.parent, nfid: @fid) do |pkt|
        case pkt
        when Rwalk then
          client.track_fid(@fid) { self.close }
          client.request(L2000::Tcreate.new(fid: @fid,
                                            name: NString.new(@path.basename),
                                            flags: @flags,
                                            mode: mode || 0644,
                                            gid: gid || 0)) do |pkt|
            case pkt
            when ErrorPayload then NonoP.maybe_call(blk, CreateError.new(pkt, path))
            else NonoP.maybe_call(blk, self)
            end
          end
        when ErrorPayload then blk.call(WalkError.new(pkt, path))
        else blk ? blk.call(TypeError.new(pkt)) : raise(TypeError.new(pkt))
        end
      end
    end

    def close &blk
      r = @io.close(&blk)
      @ready = false
      r
    end

    # todo length limited to msglen
    # todo handling multiple replies for big reads
    def read length, offset: 0, &blk
      @io.read(length, offset:, &blk)
    end

    def write data, offset: 0, length: nil, &blk
      @io.write(data, offset:, length:, &blk)
    end

    def write_one data, offset: 0, &blk
      @io.write_one(data, offset:, &blk)
    end

    def wrap_error_or_data pkt, error = Error
      case pkt
      when ErrorPayload then error.new(pkt, path)
      else pkt.data
      end
    end

    def retself value, child
      value.equal?(child) ? self : value
    end
  end
end
