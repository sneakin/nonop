require 'sg/ext'
using SG::Ext

require 'sg/defer'

class NonoP::Client
  class PendingRequest < SG::Defer::Value
    attr_reader :client, :packet
    
    def initialize client, packet, handler
      @packet = packet
      @handler = handler
      super() do
        _, result = client.process_until(tag: tag)
        result
      end
    end

    delegate :tag, to: :packet
    
    def accept v
      super(@handler.call(v))
    end
    
    def reject v
      super(@handler.call(v))
    end
  end
  
  class PendingRequests < SG::Defer::Value
    attr_reader :client, :pending, :results
    
    def initialize(client)
      @client = client
      @pending = Array.new
      @results = []
      @after = []
      super() { produce }
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

    def produce_one
      @client.process_until(tags: pending_tags).tap do |tag, r|
        @results << r
        @pending.delete_if { _1.tag == tag }
      end
    end

    def produce
      produce_one until @pending.empty?
      @after.reduce(@results) { _2.call(_1) }
    end

    def after &fn
      @after << fn
      self
    end
  end
end
