require 'sg/ext'
using SG::Ext

require_relative 'packet-data'
require_relative '../qid'

module NineP
  class Tcreate
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:name, NString ],
                   [:perm, :uint32l],
                   [:mode, :uint8],
                   [:extension, NString])

  end

  class Rcreate
    include Packet::Data
    define_packing([:qid, Qid ],
                   [:iounit, :uint32l])
  end
end
