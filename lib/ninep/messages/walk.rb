require 'sg/ext'
using SG::Ext

require_relative 'packet-data'
require_relative '../nstring'
require_relative '../qid'

module NineP
  class Twalk
    # size[4] Twalk tag[2] fid[4] newfid[4] nwname[2] nwname*(wname[s])
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:newfid, :uint32l],
                   [:nwnames, :uint16l],
                   [:wnames, NString, :nwnames])

    def pack
      self.nwnames = wnames.size
      super
    end
  end

  class Rwalk
    # size[4] Rwalk tag[2] nwqid[2] nwqid*(wqid[13])
    include Packet::Data
    define_packing([:nwqid, :uint16l],
                   [:wqid, Qid, :nwqid])

    def pack
      self.nwqid = wqid.size
      super
    end
  end
end
