require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tsymlink
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:name, NString],
                     [:target, NString],
                     [:gid, :uint32l])
    end

    class Rsymlink
      include Packet::Data
      define_packing([:qid, Qid])
    end
  end
end
