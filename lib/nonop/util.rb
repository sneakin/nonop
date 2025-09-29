require 'sg/ext'
using SG::Ext

module NonoP
  def self.vputs(*lines, io: $stderr, &blk)
    return unless $verbose
    io.puts(*lines) unless lines.blank?
    if blk
      more = blk.call
      more = [ more ] unless Array === more
      io.puts(*more) if more
    end
  end

  def self.block_string(str, block_size, offset: nil, length: nil)
    Enumerator.new do |y|
      offset = offset || 0
      length ||= str.size
      while offset < length
        block = str[offset, block_size]
        break if block.empty?
        offset += block_size
        y << block
      end
    end
  end

  def self.maybe_call(proc, ret, *args, **opts, &blk)
    proc ? proc.call(ret, *args, **opts, &blk) :
      (args.empty?? ret : [ ret, *args ])
  end

  class ComparableNil
    include Singleton
    include Comparable

    def nil?
      true
    end

    def <=> other
      other == nil ? 0 : 1
    end

    def coerce other
      [ other, other ]
    end
  end
end
