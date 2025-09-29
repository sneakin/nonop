require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NonoP
  class Tclunk
    include Packet::Data
    define_packing([:fid, :uint32l])
  end

  class Rclunk
    include Packet::Data
    define_packing()
  end
end
