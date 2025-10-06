require 'sg/ext'
using SG::Ext

module NonoP
  class BitField
    Prefix = 'BitField'

    class Instance
      # @param bf [BitField]
      # @param v [Array<[Symbol, String, Integer, Enumerable]>
      def initialize bf, *v
        @bitfield = bf
        self.value = v
      end

      # @return [BitField]
      attr_reader :bitfield
      delegate :prefix, :bits, :masks, :value_for, :key_for, :mask_or_value_for, to: :bitfield
      # @return [Integer]
      attr_reader :value

      # @param v [Symbol, String, Integer, Enumerable]
      # @return [Integer]
      # @raise TypeError
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

      # @return [BitField::Instance]
      def dup
        self.class.new(bitfield, value)
      end

      # @param bit [Integer, Symbol, String]
      # @return [self]
      def set_bit! bit
        @value |= value_for(bit)
        self
      end

      # @param bit [Integer, Symbol, String]
      # @return [self]
      def clear_bit! bit
        @value &= ~(value_for(bit))
        self
      end

      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [self]
      def set! *bits
        bits.each { set_bit!(_1) }
        self
      end

      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [self]
      def clear! *bits
        bits.each { clear_bit!(_1) }
        self
      end

      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [BitField::Instance]
      def set *bits
          dup.set!(*bits)
      end
      
      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [BitField::Instance]
      def clear *bits
          dup.clear!(*bits)
      end

      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [self]
      def mask! *bits
        @value &= mask_or_value_for(*bits)
        self
      end

      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [BitField::Instance]
      def mask *bits
          dup.mask!(*bits)
      end
      
      # @param bit [Integer]
      # @return [Boolean]
      def bit_setn? bit
        0 != (value & bit)
      end

      # @param bits [Array<[Integer, Symbol, String]>]
      # @return [Boolean]
      def bit_set? *bits
        bit_setn?(value_for(*bits))
      end

      alias & bit_set?
      alias | set

      # @return [BitField::Instance]
      def ~
          self.class.new(bits, ~value)
      end

      # @param other [BitField, Integer]
      # @return [Boolean]
      def eql? other
        other = other.value if self.class === other
        value.eql?(other)
      end

      alias == eql?

      # @return [Array<Symbol>]
      def to_a
        bits.keys.select { bit_set?(_1) }
      end

      # @return String
      def to_s
        "%%%s[%s]" % [ prefix, to_a.collect(&:to_s).join(', ') ]
      end

      alias :to_i :value

      # @param other [Object]
      # @return [Array<Integer, Integer>, Array<Object, Object>]
      def coerce other
        return [ to_i, other ] if Integer === other
        super
      end
    end

    # @param bits [Hash<Symbol, Integer>]
    # @param masks [Hash<Symbol, Integer>, nil]
    # @param prefix [String, nil]
    def initialize bits, masks = nil, prefix = nil
      @bits = bits
      @masks = masks
      @prefix = prefix || Prefix
    end

    # @return [Hash<Symbol, Integer>]
    attr_reader :bits
    # @return [Hash<Symbol, Integer>]
    attr_reader :masks
    # @return [String]
    attr_reader :prefix

    # @param bit [Integer, Symbol, String]
    # @return [Symbol]
    def key_for bit
      bits.find { _2 == bit }[0]
    end

    # @param bits [Array<[Integer, Symbol, String]>]
    # @return [Integer]
    def value_for *bits
      bits.flatten.reduce(0) { _1 | mask_or_value_for_bit(_2) }
    end

    # @param bit [Integer, Symbol, String]
    # @return [Integer]
    # @raise KeyError
    def [] bit
      value_for_bit(bit, masks)
    rescue KeyError
      value_for_bit(bit)
    end

    # @param bit [Integer, Symbol, String]
    # @param tbl [Hash<Symbol, Integer>]
    # @return [Integer]
    def value_for_bit bit, tbl = bits
      case bit
      when String then tbl.fetch(bit.to_sym)
      when Symbol then tbl.fetch(bit)
      when Integer then bit
      else raise TypeError.new("%s is not Symbol, String, or Integer." % [ bit.class ])
      end
    end

    # @param bit [Integer, Symbol, String]
    # @return [Integer]
    # @raise KeyError
    def mask_or_value_for_bit bit
      value_for_bit(bit, masks)
    rescue KeyError
      value_for_bit(bit, self.bits)
    end

    # @param bits [Array<[Integer, Symbol, String]>]
    # @return [Integer]
    def mask_or_value_for *bits
      bits.flatten.reduce(0) do
        _1 | mask_or_value_for_bit(_2)
      end
    end

    # @return [Instance]
    def make ...
        Instance.new(self, ...)
    end

    alias new make

    # @return [Integer]
    # @raise NoMethodError
    def method_missing mid, ...
        self[mid]
    rescue KeyError
      raise NoMethodError.new(mid)
    end
  end
end
