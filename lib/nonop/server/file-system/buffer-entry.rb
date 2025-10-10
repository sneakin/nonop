require 'sg/ext'
using SG::Ext

module NonoP::Server::FileSystem
  class BufferEntry < Entry
    class DataProvider < Entry::DataProvider
      # @return [BufferEntry]
      attr_reader :entry
      delegate :read, :write, :truncate, to: :entry

      # @param entry [BufferEntry]
      def initialize entry
        super()
        @entry = entry
      end
    end

    # @return [String]
    attr_accessor :data

    # @param name [String]
    # @param data [String]
    # @param umask [Integer, nil]
    def initialize name, data, umask: nil
      super(name, umask:)
      @data = data
    end

    # @return [Integer]
    def size
      data.bytesize
    end

    # @param flags [NonoP::BitField::Instance]
    # @return [OpenedEntry]
    # @raise SystemCallError
    def open flags
      oe = super(flags, DataProvider.new(self))
      if flags & [:CREATE, :TRUNC]
        oe.truncate
      end
      oe
    end

    # @param count [Integer]
    # @param offset [Integer]
    # @yield [data]
    # @yieldparam data [String]
    # @yieldreturn [String]
    # @return [String, void]
    def read count, offset = 0, &cb
      attrs[:atime_sec] = Time.now
      NonoP.maybe_call(cb, data[offset, count])
    end

    # @param size [Integer]
    # @return [self]
    # @raise SystemCallError
    def truncate size = 0
      @data = @data[0, size]
      attrs[:ctime_sec] = Time.now
      self
    end

    # @param data [String]
    # @param offset [Integer]
    # @yield [count]
    # @yieldparam count [Integer]
    # @return [Integer, void]
    # @raise SystemCallError
    def write data, offset = 0, &cb
      if offset < (@data.size - data.size)
        @data[offset, data.size] = data
      else
        @data += ("\x00" * (offset - @data.size)) + data
      end
      attrs[:mtime_sec] = Time.now
      NonoP.maybe_call(cb, data.size) # todo bytesize?
    end

    # @return [Hash<Symbol, Object>]
    def attrs
      @attrs ||= NonoP::Server::FileSystem::DEFAULT_FILE_ATTRS.
        merge(qid: qid,
              mode: NonoP::PermMode.new(data.frozen? ? :R : :RW).mask!(~umask) | :FILE)
    end

    # @param new_attrs [Hash<Symbol, Object>]
    # @return [self]
    def setattr new_attrs
      @attrs = attrs.merge(new_attrs) # todo be picky
      self
    end
  end
end
