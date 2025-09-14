require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Tclunk
    ID = 120
    include Packet::Data
    define_packing([:fid, :uint32l])
  end

  class Rclunk
    ID = 121
    include Packet::Data
    define_packing()
  end
end
