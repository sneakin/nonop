require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../nstring'

module NineP
  module L2000
    class Tattach
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:afid, :uint32l],
                     [:uname, NString],
                     [:aname, NString],
                     [:n_uname, :uint32l])
    end

    class Rattach < NineP::Rattach
    end
  end
end
