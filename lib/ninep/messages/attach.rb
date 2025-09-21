require 'sg/ext'
using SG::Ext

require_relative '../nstring'
require_relative '../qid'
require_relative 'packet-data'

module NineP
  class Tattach
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:afid, :uint32l],
                   [:uname, NString],
                   [:aname, NString])
  end

  class Rattach
    include Packet::Data
    define_packing([:aqid, Qid])
  end
end
