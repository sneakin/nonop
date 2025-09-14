require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NineP
  class Packet
    module Data
      def self.included base
        base.include SG::AttrStruct
        base.include SG::PackedStruct
        base.extend(ClassMethods)
      end

      # todo only the Coder knows about registered IDs
      module ClassMethods
        def type_id
          self.const_get('ID')
        end
      end

      def type_id
        self.class.type_id
      end
    end
  end
end  
