require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tmknod
      include Packet::Data
      define_packing([:dfid, :uint32l],
                     [:name, NString],
                     [:mode, :uint32l],
                     [:major, :uint32l],
                     [:minor, :uint32l],
                     [:gid, :uint32l])
    end

    class Rmknod
      include Packet::Data
      define_packing([:qid, Qid])
    end
  end
end
