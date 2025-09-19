require 'sg/ext'
using SG::Ext

module NineP
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
end
