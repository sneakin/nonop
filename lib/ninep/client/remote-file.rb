module NineP
  class RemoteFile
    attr_reader :client, :path, :flags, :fid, :parent_fid
    
    def initialize path, client:, flags: nil, fid: nil, parent_fid: nil, &blk
      @path = path.empty?? [] : path.split('/')
      @client = client
      @flags = flags || NineP::L2000::Topen::Flags[:RDONLY]
      @fid = fid || client.next_fid
      @parent_fid = parent_fid || 0
      client.request(NineP::Twalk.new(fid: @parent_fid,
                                      newfid: @fid,
                                      wnames: @path.collect { NineP::NString.new(_1) })) do |pkt|
        case pkt
        when Rwalk then
          client.track_fid(@fid)
          client.request(NineP::L2000::Topen.new(fid: @fid,
                                                 flags: @flags)) do |pkt|
            @ready = true
            blk&.call(self)
          end
        when ErrorPayload then blk&.call(WalkError.new(pkt, path))
        else raise TypeError.new(pkt.class)
        end
      end
    end

    def ready?
      @ready
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

    def wrap_error_or_data pkt, error = Error
      case pkt
      when ErrorPayload then error.new(pkt, path)
      else pkt.data
      end
    end
    
  end
end
