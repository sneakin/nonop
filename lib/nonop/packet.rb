require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NonoP
  class Packet
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:size, :uint32l],
                   [:type, :uint8],
                   [:tag, :uint16l],
                   [:raw_data, :string, :data_size])
    calc_attr :size, lambda { attribute_offset(:raw_data) + data.bytesize }
    attributes :coder, :data, :extra_data

    def coder
      @coder || data&.class
    end

    def pack
      if @data
        @raw_data = @data.pack
        @type ||= coder.type_id_for(@data.class)
      end
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
