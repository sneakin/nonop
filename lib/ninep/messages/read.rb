require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Tread
    ID = 116
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:offset, :uint64l],
                   [:count, :uint32l])
  end

  class Rread
    ID = 117
    include Packet::Data
    define_packing([:count, :uint32l],
                   [:data, :string, :count])
  end
end
