require 'sg/ext'
using SG::Ext

module NineP
  class RemotePath
    Separator = '/'.freeze
    attr_reader :parts, :separator
    
    def initialize path, separator: nil
      @separator = separator || Separator
      @parts = case path
               when nil then []
               when String then path.split(@separator)
               when self.class then path.parts.dup
               when Enumerable then path.to_a
               else TypeError.new(path.class)
               end
    end

    def size
      parts.size
    end

    def to_str
      parts.join(separator)
    end

    alias to_s to_str

    include Enumerable
    
    def each &blk
      parts.each(&blk)
    end
    
    def basename
      parts.last
    end
    
    def parent levels = nil, from_top: false
      if from_top
        self.class.new(parts[0, levels || (parts.size - 1)],
                       separator: separator)
      else
        self.class.new(parts[0, parts.size - (levels || 1)],
                       separator: separator)
      end
    end

    def join *new_parts
      self.class.new(parts + new_parts, separator: separator)
    end
  end
end

