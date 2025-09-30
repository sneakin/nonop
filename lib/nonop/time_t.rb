require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NonoP
  class TimeT
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:n, :uint64l])
    attributes :t
    def n= v
      self.t = case v
               when Integer then Time.at(v)
               when self.class then v.t
               when Time then v
               when nil then nil
               else raise TypeError
               end
      @n
    end
    def t= v
      return @t if v == nil && @n != nil
      raise TypeError.new("Must be Time or nil: not #{v.class}") unless nil == v || Time === v || self.class === v
      v = v.t if self.class === v
      @n = v&.to_i
      @t = v
    end

    delegate :to_i, :to_s, to: :n
    delegate :strftime, to: :t

    def self.at t
      self.new(t: Time.at(t))
    end

    def self.now
      self.new(t: Time.now)
    end
  end
end
