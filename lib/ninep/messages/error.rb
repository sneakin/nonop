require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class ErrorPayload
    attr_reader :code
  end

  def self.maybe_wrap_error pkt, error = Error
    case pkt
    when ErrorPayload then error.new(pkt, path)
    else pkt
    end
  end
  
  class Rerror < ErrorPayload
    ID = 107
    include Packet::Data
    define_packing([:code, :uint32l])
  end
end
