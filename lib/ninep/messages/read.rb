require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Tread
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:offset, :uint64l],
                   [:count, :uint32l])
  end

  class Rread
    include Packet::Data
    define_packing([:count, :uint32l],
                   [:data, :string, :count])
    calc_attr :count, lambda { data.bytesize }
  end
end
