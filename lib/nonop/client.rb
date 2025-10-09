require 'sg/ext'
using SG::Ext

require_relative 'errors'
require_relative 'client/attachment'

module NonoP
  class Client
    autoload :PendingRequest, 'nonop/client/pending-request'
    autoload :PendingRequests, 'nonop/client/pending-request'
    
    attr_reader :coder, :io, :server_info, :afid
    delegate :max_msglen, :max_msglen=, :max_datalen, to: :coder

    def initialize coder:, io:
      @coder = coder
      @io = io
      @handlers = {}
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

    def process_until tag: nil, tags: nil
      tags ||= []
      tags << tag if tag
      result = pop_waiting_result(tags)
      return result if result
      
      tags.each { @waiting_tags[_1] = true }
      @stop_loop = false
      begin
        pkt = process_one
      end until tags.include?(pkt.tag) || tags.any? { !@waiting_tags[_1] } || @stop_loop || closed?
      tags.each { @waiting_tags.delete(_1) }

      pop_waiting_result(tags)
    end

    def pop_waiting_result tags
      ready_tag = tags.find { @waiting_results[_1] }
      [ ready_tag, @waiting_results.delete(ready_tag) ] if ready_tag
    end
    
    def process_one
      pkt = read_one
      fn = @handlers.delete(pkt.tag) || method(:on_packet)
      NonoP.vputs { "Processing #{pkt.tag}" }
      ret = fn.call(pkt.data)
      @waiting_results[pkt.tag] = ret if @waiting_tags.delete(pkt.tag)
      NonoP.vputs { "Processed #{pkt.tag}" }
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
    
    # todo ditch wait_for form a PendingRequest#wait
    def request msg, wait_for: false, &handler
      tag = next_tag
      pkt = NonoP::Packet.new(tag: tag, data: msg)
      resp = PendingRequest.new(self, pkt, handler)
      add_handler(tag, resp)
      send_one(pkt)
      resp.skip_unless(wait_for).wait
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
      request(Tversion.new(msize: max_msglen,
                           version: NString.new(@coder.version))) do |pkt|
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
      end.skip_unless(wait_for).wait
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
      wait_for ||= blk == nil
      send_auth(uname:, aname:, n_uname:, credentials:) do |&cc|
        auth_attach(uname:, aname:, n_uname:, wait_for:) do |attachment|
          raise attachment if StandardError === attachment
          attachment.close(&cc).skip_unless(wait_for).wait
        end
      end.skip_unless(wait_for).wait
    end

    def send_auth uname:, n_uname:, aname:, credentials: nil, wait_for: false, &blk
      NonoP.vputs { "Authenticating #{uname.inspect} #{n_uname.inspect}" }
      auth_fid = next_fid
      result = request(L2000::Tauth.new(afid: auth_fid,
                                        uname: NString.new(uname),
                                        aname: NString.new(aname),
                                        n_uname: n_uname)) do |pkt|
        case pkt
        when ErrorPayload then raise AuthError.new(pkt)
        when Rauth then
          @afid = auth_fid
          @aqid = pkt.aqid
          if credentials
            # write credentials to afid
            io = RemoteIO.new(self, auth_fid, 'auth')
            io.write(credentials) do |total, errs|
              NonoP.vputs { "SENT AUTH: #{total} #{errs&.size}" }
              raise errs[0] unless errs == nil || errs.empty?
              blk ? blk.call { io.close.wait } : io.close.wait
            end.wait
          else
            blk&.call
          end
        else raise TypeError.new("Expected Rauth, not #{pkt}")
        end
      end.skip_unless(wait_for).wait
    end

    def clunk fid, wait_for: nil, &blk
      NonoP.vputs { "Clunking #{fid}" }
      free_fid(fid) # todo call this? default calls back.
      request(NonoP::Tclunk.new(fid: fid)) do |reply|
        NonoP.vputs { "Clunked #{fid}" }
        case reply
        when ErrorPayload then NonoP.maybe_call(blk, NonoP.maybe_wrap_error(reply, ClunkError))
        when Rclunk then NonoP.maybe_call(blk, reply)
        else raise TypeError.new(reply.class)
        end
      end.skip_unless(wait_for).wait
    end

    def attach(**opts, &blk)
      # todo #wait
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
