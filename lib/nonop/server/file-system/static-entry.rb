require 'sg/ext'
using SG::Ext

require 'pathname'

module NonoP::Server::FileSystem
  # Read only entries backed by String, Proc, or Pathname#read generated strings.
  class StaticEntry < Entry
    class DataProvider < Entry::DataProvider
      # @return [StaticEntry]
      attr_reader :entry

      # @param entry [StaticEntry]
      def initialize entry
        super()
        @entry = entry
      end

      # @param count [Integer]
      # @param offset [Integer]
      # @return [String]
      # @raise SystemCallError
      def read count, offset = 0, &cb
        return cb.call(read(count, offset)) if cb
        entry.attrs[:atime_sec] = Time.now
        entry.data[offset, count]
      end
    end

    # @param name [String]
    # @param data [String, Proc]
    # @param umask [Integer, nil]
    # @yield [void]
    # @yieldreturn [String]
    def initialize name, data = nil, umask: nil, &blk
      super(name, umask:)
      @data = data || blk
    end

    # @param p9_mode [NonoP::BitField::Instance]
    # @return [OpenedEntry]
    # @raise SystemCallError
    def open p9_mode
      ret = super(p9_mode, DataProvider.new(self))
      raise Errno::ENOTSUP if ret.writeable?
      ret
    end

    # @return [Integer]
    def size
      data.bytesize
    end

    # @return [String]
    # @raise SystemCallError
    def data
      case @data
      when Proc then @data.call.to_s
      when Pathname then @data.read
      else @data
      end
    end
  end
end
