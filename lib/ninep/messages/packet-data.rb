require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'
require_relative '../nstring'

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
