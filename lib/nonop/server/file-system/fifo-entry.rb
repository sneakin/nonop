require 'sg/ext'
using SG::Ext

module NonoP::Server::FileSystem
  # An entry that stores data per write in a FIFO.
  class FifoEntry < Entry
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
    # @param umask [Integer, nil]
    # @yield [entry, data, offset]
    # @yieldparam entry [WriteableEntry]
    # @yieldparam data [String, nil]
    # @yieldparam offset [Integer, nil]
    # @yieldreturn [String] The new file contents.
    def initialize name, umask: nil, &blk
      super(name, umask:)
      @data = []
      @cb = blk
    end

    # @return [Qid]
    def qid
      @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:APPEND],
                              version: 0,
                              path: [ hash ].pack('Q'))
    end
    
    # @return [Integer]
    def size
      data.collect(&:bytesize).sum
    end
    
    # @return [Boolean]
    def pipe?
      true
    end

    # @param flags [NonoP::BitField::Instance]
    # @return [OpenedEntry]
    # @raise SystemCallError
    def open flags
      super(flags, DataProvider.new(self))
    end

    # @param count [Integer]
    # @param offset [Integer]
    # @return [String]
    # @raise SystemCallError
    def read count, offset = 0, &cb
      return cb.call(count, offset) if cb
      return '' if data.empty?
      attrs[:atime_sec] = Time.now
      data.shift[0, count]
    end

    # @param size [Integer]
    # @return [self]
    # @raise SystemCallError
    def truncate size = 0
      @data.clear
      attrs[:ctime_sec] = Time.now
      self
    end

    # @param data [String]
    # @param offset [Integer]
    # @yield [count]
    # @yieldparam count [Integer]
    # @return [Integer, void]
    # @raise SystemCallError
    def write data, offset = 0, &blk
      @data.push(data)
      attrs[:mtime_sec] = Time.now
      @cb&.call(self, data, offset)
      NonoP.maybe_call(blk, data.size)
    end

    # @return [Hash<Symbol, Object>]
    def attrs
      @attrs ||= NonoP::Server::FileSystem::DEFAULT_FILE_ATTRS.
        merge(qid: qid,
              mode: NonoP::PermMode.new(:RW).mask!(~umask) | :FIFO)
    end

    # @param new_attrs [Hash<Symbol, Object>]
    # @return [self]
    def setattr new_attrs
      @attrs = attrs.merge(new_attrs) # todo be picky
      self
    end
  end
end
