require 'sg/ext'
using SG::Ext

require_relative 'packet-data'
require_relative '../nstring'
require_relative '../qid'

module NineP
  class Tauth
    include Packet::Data
    define_packing([:afid, :uint32l],
                   [:uname, NString],
                   [:aname, NString])
  end

  class Rauth
    include Packet::Data
    define_packing([:aqid, Qid])
  end
end
