require 'sg/ext'
using SG::Ext

module NineP
  def self.vputs(*lines, io: $stderr, &blk)
    return unless $verbose
    io.puts(*lines) unless lines.blank?
    if blk
      more = blk.call
      puts(more) if more
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

  def self.maybe_call(proc, *args, **opts, &blk)
    proc ? proc.call(*args, **opts, &blk) : args
  end
end
