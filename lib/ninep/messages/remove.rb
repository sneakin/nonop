require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Tremove
    include Packet::Data
    define_packing([:fid, :uint32l])
  end

  class Rremove
    include Packet::Data
    define_packing()
  end
end
