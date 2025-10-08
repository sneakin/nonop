require 'sg/ext'
using SG::Ext

require_relative 'errors'
require_relative 'client/attachment'

module NonoP
  class Client
    attr_reader :coder, :io, :server_info, :afid
    delegate :max_msglen, :max_msglen=, :max_datalen, to: :coder

    def initialize coder:, io:
      @coder = coder
      @io = io
      @handlers = Hash.new { lambda { self.on_packet(_1) } }
      @next_tag = 0
      @next_fid = 0
      @afid = -1
      @open_fids = []
      @free_fids = []
      @waiting_tags = {}
      @waiting_results = {}
    end

    def stop!
      @stop_loop = true
    end

    def read_loop
      @stop_loop = false
      begin
        process_one
      end until @stop_loop || closed?
      true
    rescue IOError
      false
    end

    def process_until tag: nil
      @waiting_tags[tag] = true
      @stop_loop = false
      begin
        NonoP.vputs { "Processing until #{tag.inspect} #{@waiting_tags.size} #{@waiting_results.size}" }
        pkt = process_one
      end until pkt.tag == tag || !@waiting_tags[tag] || @stop_loop || closed?
      @waiting_results.delete(tag)
    end

    def process_one
      pkt = read_one
      fn = @handlers[pkt.tag]
      @handlers.delete(pkt.tag)
      fn.call(pkt.data)
      @waiting_results[pkt.tag] = pkt if @waiting_tags.delete(pkt.tag)
      pkt
    end

    def read_one
      @coder.read_one(@io)
    end

    def on_packet pkt
      pkt
    end

    def send_one pkt
      @coder.send_one(pkt, @io)
    end

    def add_handler tag, fn
      @handlers[tag] = fn
      self
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

    # todo ditch wait_for form a Request#wait
    def request msg, wait_for: false, &handler
      tag = next_tag
      add_handler(tag, handler) if handler
      pkt = NonoP::Packet.new(tag: tag, data: msg)
      send_one(pkt)
      wait_for ? process_until(tag: tag) :  pkt
    end

    def flush
      @io.flush
    end

    def close
      close_fids
      @io.close
      stop!
    end

    def close_fids
      @open_fids.reverse.each { _2.call }
      @open_fids.clear
      self
    end

    def closed?
      @io.closed?
    end

    def start wait_for: false, &blk
      wait_for ||= blk == nil
      result = request(Tversion.new(msize: max_msglen,
                                    version: NString.new(@coder.version)),
                       wait_for: wait_for) do |pkt|
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
      wait_for ? result : self
    end

    def local_version
      coder.version
    end

    def remote_version
      server_info[:version]
    end

    def auth uname:, n_uname:, aname:, credentials:, wait_for: false, &blk
      # Authenticating with Diode requires sending an Auth packet
      # followed by attaching to the live afid. This is followed by
      # clunking the two fids, handing off to the kernel driver that
      # then attaching again with afid = -1.  The supplied block
      # should make the second attachment.
      wait_for = wait_for || blk == nil
      send_auth(uname:, aname:, n_uname:, credentials:, wait_for:) do |&cc|
        auth_attach(uname:, aname:, n_uname:, wait_for:) do |attachment|
          raise attachment if StandardError === attachment
          attachment.close(wait_for:, &cc)
        end
      end
    end

    def send_auth uname:, n_uname:, aname:, credentials: nil, wait_for: false, &blk
      NonoP.vputs { "Authenticating #{uname.inspect} #{n_uname.inspect}" }
      auth_fid = next_fid
      wait_for ||= blk == nil
      result = request(L2000::Tauth.new(afid: auth_fid,
                                        uname: NString.new(uname),
                                        aname: NString.new(aname),
                                        n_uname: n_uname),
                       wait_for:) do |pkt|
        case pkt
        when ErrorPayload then raise AuthError.new(pkt)
        when Rauth then
          @afid = auth_fid
          @aqid = pkt.aqid
          if credentials
            # write credentials to afid
            io = RemoteIO.new(self, auth_fid, 'auth')
            io.write(credentials, wait_for:) do |reply|
              raise reply if StandardError === reply
              blk ? blk.call { io.close(wait_for:) } : io.close(wait_for:)
            end
          else
            blk&.call
          end
        else raise TypeError.new("Expected Rauth, not #{pkt}")
        end
      end

      wait_for ? result : self
    end

    def clunk fid, wait_for: nil, &blk
      NonoP.vputs { "Clunking #{fid}" }
      free_fid(fid) # todo call this? default calls back.
      wait_for ||= blk == nil
      result = request(NonoP::Tclunk.new(fid: fid),
                       wait_for:) do |reply|
        NonoP.vputs { "Clunked #{fid}" }
        case reply
        when ErrorPayload then NonoP.maybe_call(blk, NonoP.maybe_wrap_error(reply, ClunkError))
        when Rclunk then NonoP.maybe_call(blk, reply)
        else raise TypeError.new(reply.class)
        end
      end

      wait_for ? result : self
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
