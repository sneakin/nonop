require 'sg/ext'
using SG::Ext

require_relative 'errors'

module NineP
  class Client
    attr_reader :server_info, :afid
    
    def initialize coder:, io:
      @coder = coder
      @io = io
      @handlers = Hash.new { lambda { self.on_packet(_1) } }
      @next_tag = 0
      @next_fid = 0
      @afid = -1
    end
    
    def read_one
      @coder.read_one(@io)
    end

    def process_one
      pkt = read_one
      fn = @handlers[pkt.tag]
      @handlers.delete(pkt.tag)
      fn.call(pkt.data)
      pkt
    end

    def on_packet pkt
      pkt
    end

    def read_loop
      @stop_loop = false
      begin
        process_one
      end until @stop_loop || closed?
      true
    end

    def process_until tag: nil
      @stop_loop = false
      pkt = nil
      begin
        pkt = process_one
      end until pkt.tag == tag || @stop_loop || closed?
      pkt
    end

    def stop!
      @stop_loop = true
    end

    def add_handler tag, fn
      @handlers[tag] = fn
      self
    end
    
    def send_one pkt
      @coder.send_one(pkt, @io)
    end

    def next_fid
      @next_fid = (@next_fid + 1) & 0xFFFF
    end
    
    def next_tag
      @next_tag = (@next_tag + 1) & 0xFFFF
    end
    
    def request msg, wait_for: false, &handler
      tag = next_tag
      add_handler(tag, handler) if handler
      pkt = NineP::Packet.new(tag: tag, data: msg)
      send_one(pkt)
      if wait_for
        return process_until(tag: tag)
      else
        return pkt
      end
    end
    
    def flush
      @io.flush
    end
    
    def close
      @io.close
    end
    
    def closed?
      @io.closed?
    end

    delegate :max_msglen, :max_msglen=, to: :coder

    def start &blk
      request(Tversion.new(msize: 65535,
                           version: NString.new(@coder.version)),
                    wait_for: blk == nil) do |pkt|
        case pkt
        when ErrorPayload then raise StartError(pkt)
        when Rversion then
          @server_info = {
            version: pkt.version,
            msize: pkt.msize
          }
        end
        blk&.call(pkt)
      end
      self
    end

    def auth uname:, n_uname:, aname:, &blk
      request(L2000::Tauth.new(afid: 0, # todo attach first?
                               uname: NString.new(uname),
                               aname: NString.new(aname),
                               n_uname: n_uname),
              wait_for: blk == nil) do |pkt|
        case pkt
        when ErrorPayload then raise AuthError.new(pkt) if pkt.code != 2 && !blk
        when Rauth then @afid = pkt.afid
        end
        blk&.call(pkt)
      end
      self
    end

    def attach afid: nil, uname:, n_uname:, aname:, &blk
      request(NineP::L2000::Tattach.new(fid: 0,
                                        afid: afid || -1,
                                        uname: NineP::NString.new(uname),
                                        aname: NineP::NString.new(aname),
                                        n_uname: n_uname || -1),
              wait_for: blk == nil) do |pkt|
        case pkt
        when ErrorPayload then raise AttachError.new(pkt)
        when Rattach then
          @qid = pkt.aqid
        end
        blk&.call(pkt)
      end
      self
    end

    def clunk fid, async: nil, &blk
      request(NineP::Tclunk.new(fid: fid),
              wait_for: async != true && blk == nil,
              &blk)
      self
    end

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
        client.request(NineP::Tclunk.new(fid: fid))
        self
      end

      # todo length limited to msglen
      def read length, offset: 0, &blk
        req = client.request(NineP::Tread.new(fid: fid,
                                        offset: offset,
                                        count: length),
                       wait_for: blk == nil) do |result|
          blk&.call(ErrorPayload === result ? ReadError.new(result, path.join('/')) : result.data)
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
    end

    class RemoteDir
      def close
      end
    end

    class WalkTarget
      attr_reader :fid
      
      def initialize path
      end
      
      def close
      end
    end
    
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
        client.request(NineP::L2000::Tattach.new(fid: @fid,
                                          afid: @afid,
                                          uname: NineP::NString.new(uname),
                                          aname: NineP::NString.new(aname),
                                          n_uname: n_uname)) do |pkt|
          case pkt
          when ErrorPayload then raise AttachError.new(pkt)
          when Rattach then
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
end
