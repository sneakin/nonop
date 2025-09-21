require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tlink
      include Packet::Data
      # size[4] Tlink tag[2] dfid[4] fid[4] name[s]
      define_packing([:dfid, :uint32l],
                     [:fid, :uint32l],
                     [:name, NString])
    end

    class Rlink
      include Packet::Data
      # size[4] Rmkdir tag[2] qid[13]
      define_packing([:qid, Qid])
    end
  end
end
