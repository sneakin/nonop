require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NineP
  class NString
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:size, :uint16l],
                   [:value, :string, :size])

    def initialize *opts
      case opts
        in [] then @size = 0
        in [ Integer, String ] then @size, @value = opts
        in [ Integer ] then @size = opts[0]
        in [ Hash ] then @size, @value = opts[0].pick(:size, :value)
        in [ String ] then @size, @value = [ opts[0].size, opts[0] ]
      end
      @value ||= "\x00" * @size
    end
        
    def size
      @size || value.size
    end
    
    def to_s
      value
    end

    def == other
      case other
      when self.class then value == other.value
      else value == other.to_s
      end
    end
  end
end
