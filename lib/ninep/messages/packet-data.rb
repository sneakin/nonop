require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NineP
  class Packet
    module Data
      def self.included base
        base.include SG::AttrStruct
        base.include SG::PackedStruct
      end
    end
  end
end  
