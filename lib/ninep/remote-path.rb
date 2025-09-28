require 'sg/ext'
using SG::Ext

module NineP
  class RemotePath
    Separator = '/'.freeze
    # @return [Array<String>]
    attr_reader :parts
    # @return [String]
    attr_reader :separator

    # @param path [String, Enumerable, RemotePath, nil]
    # @param separator [String]
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

    # @return [Integer]
    def size
      parts.size
    end

    # @return [String]
    def to_str
      parts.join(separator)
    end

    alias to_s to_str

    include Enumerable

    # @yield [part]
    # @yieldparam part [String[
    # @yieldreturn [Object]
    # @return [Enumerator, Array<String>
    def each &blk
      parts.each(&blk)
    end

    # @return [String]
    def basename
      parts.last
    end

    # @param levels [Integer, nil]
    # @param from_top [Boolean]
    # @return [RemotePath]
    def parent levels = nil, from_top: false
      if from_top
        self.class.new(parts[0, levels || (parts.size - 1)],
                       separator: separator)
      else
        self.class.new(parts[0, parts.size - (levels || 1)],
                       separator: separator)
      end
    end

    # @param new_parts [Array<String>]
    # @return [RemotePath]
    def join *new_parts
      self.class.new(parts + new_parts, separator: separator)
    end
  end
end
