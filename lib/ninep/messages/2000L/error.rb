require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../error'

module NineP
  module L2000
    class Rerror
      include ErrorPayload
      include Packet::Data
      define_packing([:code, :uint32l])
    end
  end
end
