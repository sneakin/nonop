require 'sg/ext'
using SG::Ext

module NineP
  class Client
    def initialize coder:, io:
      @coder = coder
      @io = io
    end
    
    def read_one
      @coder.read_one(@io)
    end
    
    def send_one pkt
      @coder.send_one(pkt, @io)
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
  end
end
