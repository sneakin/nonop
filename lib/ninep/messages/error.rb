require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class ErrorPayload
    attr_reader :code
  end
  
  class Rerror < ErrorPayload
    ID = 107
    include Packet::Data
    define_packing([:code, :uint32l])
  end
end
