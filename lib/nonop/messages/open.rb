require 'sg/ext'
using SG::Ext

require_relative 'packet-data'
require_relative '../qid'

module NonoP
  class Topen
    # size[4] Tlopen tag[2] fid[4] mode[1]
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:flags, :uint8])
  end

  class Ropen
    # size[4] Rlopen tag[2] qid[13] iounit[4]
    include Packet::Data
    define_packing([:qid, Qid],
                   [:iounit, :uint32l])
  end
end
