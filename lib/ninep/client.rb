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
      @open_fids = []
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
      @open_fids.delete_if { _1[0] == fid }
      @open_fids << [ fid, blk || lambda { self.clunk(fid) } ]
    end

    def free_fid fid
      @open_fids.delete_if { _1[0] == fid }
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
      @open_fids.reverse.each { _2.call }
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
        end
        blk&.call(pkt)
      end
      self
    end

    def local_version
      coder.version
    end

    def remote_version
      server_info[:version]
    end

    def auth uname:, n_uname:, aname:, credentials:, &blk
      # Authenticating with Diode requires sending an Auth packet
      # followed by attaching to the live afid. This is followed by
      # clunking the two fids and attaching again with afid = -1.
      # The supplied block should make the second attachment.
      send_auth(uname:, aname:, n_uname:) do |io, &cc|
        raise io if StandardError === io
        
        auth_cc = lambda do |reply = nil, &cc|
          auth_attach(uname: '', aname:, n_uname:) do |attachment|
            raise attachment if StandardError === attachment
            cc.call do |*a|
              attachment.close(&blk)
            end
          end
        end

        if credentials
          io.write(credentials) { auth_cc.call(&cc) }
        else
          auth_cc.call(&cc)
        end
      end
    end
    
    def send_auth uname:, n_uname:, aname:, &blk
      NineP.vputs { "Authenticating #{n_uname}" }
      auth_fid = 0
      request(L2000::Tauth.new(afid: auth_fid,
                               uname: NString.new(uname),
                               aname: NString.new(aname),
                               n_uname: n_uname),
              wait_for: blk == nil) do |pkt|
        case pkt
        when ErrorPayload then
          if pkt.code != 2 && !blk
            raise AuthError.new(pkt)
          else
            blk.call(NineP.maybe_wrap_error(pkt, AuthError))
          end
        when Rauth then
          @afid = auth_fid
          @aqid = pkt.aqid
          # write credentials to afid
          io = RemoteIO.new(self, auth_fid, 'auth')
          blk&.call(io) do |&cc|
            io.close(&cc)
          end
        else blk&.call(pkt)
        end
      end
      self
    end

    def clunk fid, async: nil, &blk
      NineP.vputs { "Clunking #{fid}" }
      free_fid(fid) # todo call this? default calls back.
      result = request(NineP::Tclunk.new(fid: fid),
              wait_for: async != true && blk == nil) do |reply|
        case reply
        when ErrorPayload then blk&.call(NineP.maybe_wrap_error(reply, ClunkError))
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

    def auth_attach(**opts, &blk)
      Attachment.new(**opts.merge(client: self, afid: @afid), &blk)
    end

    def flush_tag oldtag, &blk
      request(Tflush.new(oldtag: oldtag), &blk)
    end
  end
end
