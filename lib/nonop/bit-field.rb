require 'sg/ext'
using SG::Ext

module NonoP
  class BitField
    Prefix = 'BitField'

    class Instance
      def initialize bf, *v
        @bitfield = bf
        self.value = v
      end

      attr_reader :bitfield
      delegate :prefix, :bits, :masks, :value_for, :key_for, :mask_or_value_for, to: :bitfield
      attr_reader :value

      def value= v
        v = v.first if Enumerable === v && v.size == 1
        v ||= 0
        @value = case v
                 when self.class then
                   raise TypeError.new("BitField mismatch: #{bitfield.prefix} #{v.prefix.inspect}") unless bitfield.equal?(v.bitfield)
                   v.value
                 when Enumerable, Symbol, String then value_for(*v)
                 when Integer then v
                 else raise TypeError.new("#{v.inspect} is unacceptable")
                 end
      end

      def dup
        self.class.new(bitfield, value)
      end
      
      def set_bit! bit
        @value |= value_for(bit)
        self
      end

      def clear_bit! bit
        @value &= ~(value_for(bit))
        self
      end

      def set! *bits
        bits.each { set_bit!(_1) }
        self
      end

      def clear! *bits
        bits.each { clear_bit!(_1) }
        self
      end

      def set ...
          dup.set!(...)
      end
      
      def clear ...
          dup.clear!(...)
      end

      def mask! *bits
        @value &= mask_or_value_for(*bits)
        self
      end

      def mask ...
          dup.mask!(...)
      end
      
      def bit_setn? bit
        0 != (value & bit)
      end

      def bit_set? *bits
        bit_setn?(value_for(*bits))
      end

      alias & bit_set?
      alias | set

      def ~
          self.class.new(bits, ~value)
      end

      def eql? other
        other = other.value if self.class === other
        value.eql?(other)
      end

      alias == eql?
      
      def to_a
        bits.keys.select { bit_set?(_1) }
      end
      
      def to_s
        "%%%s[%s]" % [ prefix, to_a.collect(&:to_s).join(', ') ]
      end

      alias :to_i :value

      def coerce other
        return [ to_i, other ] if Integer === other
        super
      end
    end
    
    def initialize bits, masks = nil, prefix = nil
      @bits = bits
      @masks = masks
      @prefix = prefix || Prefix
    end

    attr_reader :bits
    attr_reader :masks
    attr_reader :prefix

    def key_for bit
      bits.find { _2 == bit }[0]
    end

    def value_for *bits
      bits.flatten.reduce(0) { _1 | mask_or_value_for_bit(_2) }
    end

    def [] bit
      value_for_bit(bit, masks)
    rescue KeyError
      value_for_bit(bit)
    end

    def value_for_bit bit, tbl = bits
      case bit
      when String then tbl.fetch(bit.to_sym)
      when Symbol then tbl.fetch(bit)
      when Integer then bit
      else raise TypeError.new("%s is not Symbol, String, or Integer." % [ bit.class ])
      end
    end

    def mask_or_value_for_bit bit
      value_for_bit(bit, masks)
    rescue KeyError
      value_for_bit(bit, self.bits)
    end

    def mask_or_value_for *bits
      bits.flatten.reduce(0) do
        _1 | mask_or_value_for_bit(_2)
      end
    end

    def make ...
        Instance.new(self, ...)
    end

    alias new make

    def method_missing mid, ...
        self[mid]
    rescue KeyError
      raise NoMethodError.new(mid)
    end
  end
end
