require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Topen
      # size[4] Tlopen tag[2] fid[4] flags[4]
      ID = 12
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:flags, :uint32l])
    end

    class Ropen
      # size[4] Rlopen tag[2] qid[13] iounit[4]
      ID = 13
      include Packet::Data
      define_packing([:qid, Qid],
                     [:iounit, :uint32l])
    end
  end
end
