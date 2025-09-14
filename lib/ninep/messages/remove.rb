require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Tremove
    ID = 122
    include Packet::Data
    define_packing([:fid, :uint32l])
  end

  class Rremove
    ID = 123
    include Packet::Data
    define_packing()
  end
end
