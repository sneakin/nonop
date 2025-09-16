module NineP
  class RemoteDir
    READ_SIZE = 4096
    
    attr_reader :client, :path, :flags, :fid, :parent_fid
    
    def initialize path, client:, flags: nil, fid: nil, parent_fid: nil, &blk
      @path = path.empty?? [] : path.split('/')
      @client = client
      @flags = flags || NineP::L2000::Topen::Flags[:DIRECTORY]
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

    # todo an async version to complement an enumerable
    def entries count: nil, offset: nil, &blk
      return to_enum(__method__, count:, offset:) unless blk
      
      count ||= READ_SIZE
      offset ||= 0
      readdir(count, offset, wait_for: true) do |dir|
        break if StandardError === dir
        dir.entries.each(&blk)
        if dir.entries.size == count
          entries(count, offset + dir.entries.size, &blk)
        end
      end
    end

    def readdir count, offset = 0, wait_for: nil, &blk
      client.request(NineP::L2000::Treaddir.new(fid: fid,
                                                offset: offset,
                                                count: count),
                     wait_for: wait_for) do |result|
        blk.call(NineP.maybe_wrap_error(result), ReadError)
      end
    end
  end
end
