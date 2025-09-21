require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Treadlink
      include Packet::Data
      define_packing([:fid, :uint32l])
    end

    class Rreadlink
      include Packet::Data
      define_packing([:target, NString])
    end
  end
end
