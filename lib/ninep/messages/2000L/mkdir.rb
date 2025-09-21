require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tmkdir
      include Packet::Data
      # size[4] Tmkdir tag[2] dfid[4] name[s] mode[4] gid[4]
      define_packing([:dfid, :uint32l],
                     [:name, NString],
                     [:mode, :uint32l],
                     [:gid, :uint32l])
    end

    class Rmkdir
      include Packet::Data
      # size[4] Rmkdir tag[2] qid[13]
      define_packing([:qid, Qid])
    end
  end
end
