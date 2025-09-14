require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Rerror
    ID = 7
    include Packet::Data
    define_packing([:code, :uint32l])
  end
end
