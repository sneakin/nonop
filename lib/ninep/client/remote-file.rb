require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'

module NineP
  class RemoteFile
    attr_reader :client, :path, :flags, :fid, :parent_fid
    
    def initialize path, client:, flags: nil, fid: nil, parent_fid: nil, mode: nil, gid: nil, &blk
      @path = path.empty?? [] : path.split('/')
      @client = client
      @flags = L2000::Topen.flag_mask(flags || [:RDONLY])
      @fid = fid || client.next_fid
      @parent_fid = parent_fid || 0

      open(mode: mode, gid: gid, &blk)
    end

    def open mode: nil, gid: nil, &blk
      client.request(NineP::Twalk.new(fid: @parent_fid,
                                      newfid: @fid,
                                      wnames: @path.collect { NineP::NString.new(_1) })) do |pkt|
        case pkt
        when Rwalk then
          client.track_fid(@fid) # todo falsify ready
          client.request(NineP::L2000::Topen.new(fid: @fid,
                                                 flags: @flags)) do |pkt|
            if ErrorPayload === pkt
              blk&.call(OpenError.new(pkt))
            else
              @ready = true
              blk&.call(self)
            end
          end
        when ErrorPayload then
          if 0 != (@flags & NineP::L2000::Topen::Flags[:CREATE])
            create(mode: mode, gid: gid, &blk)
          else
            blk&.call(WalkError.new(pkt, @path.join('/')))
          end
        else blk&.call(TypeError.new(pkt))
        end
      end
    end

    def ready?
      @ready
    end

    def create mode: nil, gid: nil, &blk
      client.request(NineP::Twalk.new(fid: @parent_fid,
                                      newfid: @fid,
                                      wnames: [])) do |pkt|
        case pkt
        when Rwalk then
          client.track_fid(@fid)
          client.request(L2000::Tcreate.new(fid: @fid,
                                            name: NString.new(@path.last),
                                            flags: @flags,
                                            mode: mode || 0644,
                                            gid: gid || 0)) do |pkt|
            case pkt
            when ErrorPayload then blk&.call(CreateError.new(pkt, path.join('/')))
            else blk&.call(self)
            end
          end
        when ErrorPayload then blk&.call(WalkError.new(pkt, path.join('/')))
        else raise TypeError.new(pkt)
        end
      end
    end
    
    def close
      client.clunk(fid)
      self
    end

    # todo length limited to msglen
    def read length, offset: 0, &blk
      raise ArgumentError.new("Length %i must be 1...%i" % [ length, client.max_datalen ]) unless (1..client.max_datalen) === length
      raise ArgumentError.new("Offset must be positive") if offset < 0
      
      req = client.request(NineP::Tread.new(fid: fid,
                                            offset: offset,
                                            count: length),
                           wait_for: blk == nil) do |result|
        blk&.call(wrap_error_or_data(result, ReadError))
      end

      if blk
        self
      else
        case req.data
        when Rread then return req.data.data
        when ErrorPayload then raise ReadError.new(req.data, path)
        else raise TypeError.new(req)
        end
      end
    end

    def write data, offset: 0, length: nil, &blk
      raise ArgumentError.new("Offset must be positive") if offset < 0

      length ||= data.size
      block_size = client.max_datalen
      slices = NineP.block_string(data, block_size, length: length)
      results = Async.reduce(slices, 0, offset) do |to_send, counter, offset, &cc|
        if to_send.blank?
          cc.call(true, counter, offset, &blk)
          next
        end

        write_one(to_send, offset: offset) do |result|
          if ErrorPayload === result
            cc.call(result, counter, offset, &blk)
          elsif result.count == to_send.bytesize
            cc.call(false, counter + result.count, offset + result.count, &blk)
          else
            cc.call(true, counter + result.count, offset + result.count, &blk)
          end
        end
      end
      
      if blk
        self
      else
        raise WriteError.new(err, path) if ErrorPayload === results
        return results[0]
      end
    end
    
    def write_one data, offset: 0, &blk
      raise ArgumentError.new("Length %i must be 1...%i" % [ data.bytesize, client.max_datalen ]) unless (1..client.max_datalen) === data.bytesize
      raise ArgumentError.new("Offset must be positive") if offset < 0

      req = client.request(Twrite.new(fid: fid, offset: offset, data: data),
                     wait_for: blk == nil) do |result|
        blk&.call(NineP.maybe_wrap_error(result, WriteError))
      end
      
      if blk
        self
      else
        case req.data
        when Rwrite then return req.data.data
        when ErrorPayload then raise WriteError.new(req.data, path)
        else raise TypeError.new(req)
        end
      end
    end
    
    def wrap_error_or_data pkt, error = Error
      case pkt
      when ErrorPayload then error.new(pkt, path)
      else pkt.data
      end
    end
    
  end
end
