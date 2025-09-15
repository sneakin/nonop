require 'sg/ext'
using SG::Ext

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
      process_until(tag: tag) if wait_for
      return pkt
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

    class Error < RuntimeError
      def initialize code
        super("Code #{code}")
      end
    end

    class StartError < Error
    end
    class AuthError < Error
    end
    class AttachError < Error
    end

    def start &blk
      request(Tversion.new(msize: 65535,
                           version: NString.new(@coder.version)),
                    wait_for: blk == nil) do |pkt|
        case pkt
        when Rerror then raise StartError(pkt.code)
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
        when Rerror then raise AuthError.new(pkt.code) if pkt.code != 2 && !blk
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
        when Rerror then raise AttachError.new(pkt.code)
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
  end
end
