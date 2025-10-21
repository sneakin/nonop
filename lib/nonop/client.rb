require 'sg/ext'
using SG::Ext

require 'sg/promise'

require_relative 'decoder'
require_relative 'errors'
require_relative 'client/attachment'

module NonoP
  class Client
    autoload :PendingRequest, 'nonop/client/pending-request'
    autoload :PendingRequests, 'nonop/client/pending-request'
    autoload :PendingValue, 'nonop/client/pending-value'
    autoload :Promise, 'nonop/client/promise'
    
    attr_reader :coder, :io, :server_info
    delegate :max_msglen, :max_msglen=, :max_datalen, to: :coder

    def initialize coder: nil, io:
      @coder = coder || NonoP.coder_for('9P2000.L')
      @io = io
      @handlers = {}
      @next_tag = 0
      @next_fid = 0
      @open_fids = []
      @free_fids = []
      @waiting_tags = {}
      @waiting_results = {}
      @authenticated = {}
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
      end until(tags.include?(pkt.tag) ||
              tags.any? { !@waiting_tags[_1] } ||
              @stop_loop ||
              closed?)
      
      tags.each { @waiting_tags.delete(_1) }
      pop_waiting_result(tags)
    rescue IOError
      nil
    end

    def pop_waiting_result tags
      ready_tag = tags.find { @waiting_results[_1] }
      [ ready_tag, @waiting_results.delete(ready_tag)&.data ] if ready_tag
    end
    
    def process_one
      pkt = read_one
      NonoP.vputs { "Processing #{pkt.tag} #{@waiting_tags.keys.inspect}" }
      fn = @handlers.delete(pkt.tag) || method(:on_packet)
      # todo reject errors
      # @live_tags[pkt.tag] = pkt
      @waiting_results[pkt.tag] = pkt if @waiting_tags.delete(pkt.tag)
      ret = fn.accept(pkt.data)
      NonoP.vputs { "Processed #{pkt.tag} #{@waiting_tags.keys.inspect}" }
      raise ret if Exception === ret
      # raise Error.new(ret) if ErrorPayload === ret
      pkt
    rescue
      NonoP.vputs { [ "Threw #{$!.class}: #{$!}", *$!.backtrace ] }
      fn&.reject($!)
      raise
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
    
    def request msg, promise = nil, &handler
      wait_for_auth
      tag = next_tag
      pkt = NonoP::Packet.new(tag: tag, data: msg)
      promise ||= SG::Promise.new.and_then(&handler)
      resp = PendingRequest.new(self, pkt, promise)
      add_handler(tag, resp)
      send_one(pkt)
      resp
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

    def start &blk
      request(Tversion.new(msize: max_msglen,
                           version: NString.new(@coder.version))) do |pkt|
        case pkt
        when ErrorPayload then raise StartError.new(pkt)
        when Rversion then
          @max_msglen = [ max_msglen, pkt.msize ].min
          @server_info = {
            version: pkt.version.value,
            msize: pkt.msize
          }
        end
        blk&.call(pkt)
      end.wait
    end

    def local_version
      coder.version
    end

    def remote_version
      server_info[:version]
    end

    def authenticated_for? aname
      @authenticated.has_key?(aname)
    end
    
    def authenticated?
      !@authenticated.empty?
    end
    
    def wait_for_auth
      NonoP.vputs { "Waiting? #{@in_auth} #{@auth_prom} #{@auth_prom&.ready?}" }
      if !@in_auth && @auth_prom != nil && !@auth_prom.ready?
        NonoP.vputs { "Waiting!! #{@in_auth} #{@auth_prom} #{@auth_prom&.ready?}" }
        @auth_prom.wait
        @in_auth = false
      end
    end
    
    def auth(uname:, n_uname:, aname:, credentials:)
      # Authenticating with Diode requires sending an Auth packet
      # followed by attaching to the live afid. This is followed by
      # clunking the two fids, handing off to the kernel driver that
      # then attaching again with afid = -1 as the user of the
      # accessing process.
      @auth_prom = Promise.new(self).
        and_then { @in_auth = true }.
        and_then { send_auth(uname:, aname:, n_uname:) }.
        and_then { write_creds(credentials, _1.wait) }.
        and_then { |io| auth_attach(uname:, aname:, n_uname:, afid: io.fid).
                   wait.tap { |a| track_fid(a.fid) { a.close }; io.close } }.
        and_then { update_state(uname:, aname:, n_uname:, attachment: _1) }
    end
    
    def clunk fid, &blk
      NonoP.vputs { "Clunking #{fid}" }
      free_fid(fid) # todo call this? default calls back.
      request(NonoP::Tclunk.new(fid: fid)) do |reply|
        NonoP.vputs { "Clunked #{fid}" }
        case reply
        when Rclunk then NonoP.maybe_call(blk, reply)
        when ErrorPayload then NonoP.maybe_call(blk, NonoP.maybe_wrap_error(reply, ClunkError))
        else raise TypeError.new(reply)
        end
      end
    end

    def attach(**opts, &blk)
      Attachment.new(**opts.merge(client: self), &blk)
    end

    def auth_attach(**opts, &blk)
      # todo get from @authenticated
      Attachment.new(**opts.merge(client: self), &blk)
    end

    def flush_tag oldtag, &blk
      request(Tflush.new(oldtag: oldtag), &blk)
    end

    def auth_attachment_for aname
      @authenticated.fetch(aname).fetch(:attachment)
    end
    
    private

    def send_auth(uname:, n_uname:, aname:)
      NonoP.vputs { "Authenticating #{uname.inspect} #{n_uname.inspect}" }
      auth_fid = next_fid
      request(L2000::Tauth.new(afid: auth_fid,
                               uname: NString.new(uname),
                               aname: NString.new(aname),
                               n_uname: n_uname)) do |pkt|
        case pkt
        when Rauth then auth_fid
        when ErrorPayload then raise AuthError.new(pkt)
        when Exception then raise(pkt)
        else raise TypeError.new("Expected Rauth, not #{pkt}")
        end
      end
    end
    
    def write_creds credentials, afid
      NonoP.vputs { "write creds" }
      # write credentials to afid
      req = nil
      io = RemoteIO.new(self, afid, 'auth')
      req = io.write(credentials) do |total, errs|
        NonoP.vputs { "SENT AUTH: #{total} #{errs&.size}" }
        raise errs[0] unless errs == nil || errs.empty?
        io
      end.wait
      io
    end

    def update_state uname:, n_uname:, aname:, attachment:
        NonoP.vputs { "Updating state #{uname} #{aname}" }
      @authenticated[aname] = { uname:, n_uname:, aname:, attachment: }
      :yes
    end
  end
end
