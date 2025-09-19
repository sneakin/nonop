require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tcreate
      ID = 14
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:name, NString ],
                     [:flags, :uint32l],
                     [:mode, :uint32l],
                     [:gid, :uint32l])

    end

    class Rcreate
      ID = 15
      include Packet::Data
      define_packing([:qid, Qid ],
                     [:iounit, :uint32l])
    end
  end
end
