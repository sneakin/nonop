require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NineP
  class Packet
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:size, :uint32l],
                   [:type, :uint8],
                   [:tag, :uint16l],
                   [:raw_data, :string, :data_size])
    
    attributes :coder, :data, :extra_data
    
    def size
      @size || (attribute_offset(:raw_data) + data.bytesize)
    end

    def coder
      @coder || data&.class
    end
    
    def pack
      @raw_data = @data.pack if @data
      super
    end
    
    def data_size
      size - attribute_offset(:raw_data)
    end

    def data
      return @data if @data
      @data, @extra_data = coder.unpack(@raw_data)
      @data
    end
  end
end
