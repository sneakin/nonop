require 'sg/ext'
using SG::Ext

module NonoP::Server::FileSystem
  # An entry that has dynamically generated contents that buffers writes for an updating callback.
  class WriteableEntry < BufferEntry
    # @param name [String]
    # @param umask [Integer, nil]
    # @yield [entry, data, offset]
    # @yieldparam entry [WriteableEntry]
    # @yieldparam data [String, nil]
    # @yieldparam offset [Integer, nil]
    # @yieldreturn [String] The new file contents.
    def initialize name, umask: nil, &blk
      super(name, blk.call(self), umask:)
      @cb = blk
    end

    # @param data [String]
    # @param offset [Integer]
    # @return [Integer]
    # @raise SystemCallError
    def write data, offset = 0
      n = super
      @cb&.call(self, data, offset)
      n
    end
  end
end
