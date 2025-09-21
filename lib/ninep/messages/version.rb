require 'sg/ext'
using SG::Ext

require_relative 'packet-data'
require_relative '../nstring'

module NineP
  class Tversion
    include Packet::Data
    define_packing([:msize, :uint32l],
                   [:version, NString])
  end

  class Rversion < Tversion
  end
end
