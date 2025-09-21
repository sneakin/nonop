require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../nstring'

module NineP
  module L2000
    class Tauth
      include Packet::Data
      define_packing([:afid, :uint32l],
                     [:uname, NString],
                     [:aname, NString],
                     [:n_uname, :uint32l]) # 9p2000.L only
    end
  end
end
