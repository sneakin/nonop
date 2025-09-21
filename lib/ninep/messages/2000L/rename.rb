require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Trename
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:dfid, :uint32l],
                     [:name, NString])
    end

    class Rrename
      include Packet::Data
      define_packing()
    end
  end
end
