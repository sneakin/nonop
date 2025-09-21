require 'sg/ext'
using SG::Ext

require_relative 'errors'
require_relative 'client/attachment'

module NineP
  class Client
    attr_reader :coder, :io, :buffer_size, :server_info, :afid
    
    def initialize coder:, io:
      @coder = coder
      @io = io
      @handlers = Hash.new { lambda { self.on_packet(_1) } }
      @next_tag = 0
      @next_fid = 0
      @afid = -1
      @open_fids = {}
      @free_fids = []
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
      f = @free_fids.pop
      return f if f
      @next_fid = (@next_fid + 1) & 0xFFFF
    end

    def track_fid fid, &blk
      @open_fids[fid] = blk || lambda { self.clunk(fid) }
    end

    def free_fid fid
      @open_fids.delete(fid)
      @free_fids.push(fid)
      self
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
      close_fids
      @io.close
    end

    def close_fids
      @open_fids.each { _2.call }
      @open_fids.clear
      self
    end
    
    def closed?
      @io.closed?
    end

    delegate :max_msglen, :max_msglen=, :max_datalen, to: :coder

    def start &blk
      request(Tversion.new(msize: max_msglen,
                           version: NString.new(@coder.version)),
                    wait_for: blk == nil) do |pkt|
        case pkt
        when ErrorPayload then raise StartError.new(pkt)
        when Rversion then
          @max_msglen = [ max_msglen, pkt.msize ].min
          @server_info = {
            version: pkt.version,
            msize: pkt.msize
          }
          track_fid(0)
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

    def clunk fid, async: nil, &blk
      free_fid(fid) # todo call this? default calls back.
      result = request(NineP::Tclunk.new(fid: fid),
              wait_for: async != true && blk == nil) do |reply|
        case reply
        when ErrorPayload then blk&.call(maybe_wrap_error(reply, ClunkError))
        when Rclunk then blk&.call(reply)
        else raise TypeError.new(reply.class)
        end
      end

      if blk || async
        self
      else
        result
      end
    end

    def attach(**opts, &blk)
      Attachment.new(**opts.merge(client: self), &blk)
    end

    def flush_tag oldtag, &blk
      request(Tflush.new(oldtag: oldtag), &blk)
    end
  end
end
