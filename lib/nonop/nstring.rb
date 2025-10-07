require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NonoP
  class NString
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:size, :uint16l],
                   [:value, :string, :size])
    calc_attr :size, lambda { value.bytesize }

    def initialize *opts
      super()
      case opts
        in [] then @size = 0
        in [ nil ] then @size = 0
        in [ Integer, String ] then @size, @value = opts
        in [ Integer ] then @size = opts[0]
        in [ Hash ] then @size, @value = opts[0].pick(:size, :value)
        in [ String ] then @size, @value = [ opts[0].size, opts[0] ]
      end
      @value ||= "\x00" * @size
    end

    def to_s
      value
    end

    alias to_str to_s

    def == other
      case other
      when self.class then value == other.value
      when String then value == other
      else false
      end
    end

    def <=> other
      case other
      when self.class then value <=> other.value
      else value <=> other.to_s
      end
    end
  end
end
