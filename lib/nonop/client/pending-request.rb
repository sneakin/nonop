require 'sg/ext'
using SG::Ext

class NonoP::Client
  class PendingRequest
    def initialize client, pkt, handler
      @client = client
      @pkt = pkt
      @handler = handler
    end

    def tag
      @pkt.tag
    end
    
    def call response
      @result = @handler ? @handler.call(response) : response
    end
    
    def wait
      if @result
        @result
      else
        _, result = @client.process_until(tag: @pkt.tag)
        result
      end
    end

    def ready?
      @result != nil
    end

    def result
      @result
    end
  end

  class PendingRequests
    attr_reader :client, :pending, :results
    
    def initialize(client)
      @client = client
      @pending = Array.new
      @results = []
      @after = []
    end

    delegate :size, :empty?, :blank?, to: :pending

    def results_size
      @results.size
    end
    
    def << other
      @pending << other
      self
    end

    def pending?
      !@pending.empty?
    end

    def pending_tags
      @pending.collect(&:tag)
    end

    def wait_one
      @client.process_until(tags: pending_tags).tap do |tag, r|
        NonoP.vputs { "Waited for #{tag}" }
        @results << r
        @pending.delete_if { _1.tag == tag }
      end
    end

    def wait
      wait_one until @pending.empty?
      @after.reduce(@results) { _2.call(_1) }
    end

    def after &fn
      @after << fn
      self
    end
  end
end
