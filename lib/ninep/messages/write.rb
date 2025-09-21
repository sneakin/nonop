require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Twrite
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:offset, :uint64l],
                   [:count, :uint32l],
                   [:data, :string, :count])

    def pack
      self.count = data.bytesize
      super
    end
  end

  class Rwrite
    include Packet::Data
    define_packing([:count, :uint32l])
  end
end
