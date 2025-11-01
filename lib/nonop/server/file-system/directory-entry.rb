require 'sg/ext'
using SG::Ext

module NonoP::Server::FileSystem
  class DirectoryEntry < Entry
    class DataProvider < Entry::DataProvider
      # @return [DirectoryEntry]
      attr_reader :entry

      # @param entry [DirectoryEntry]
      def initialize entry
        @entry = entry
      end

      # @param count [Integer]
      # @param offset [Integer]
      # @return [Array<Dirent>]
      # @raise SystemCallError
      def readdir count, offset = 0
        entry.attrs[:atime_sec] = Time.now
        entry.readdir(count, offset)
      end
    end

    # @param name [String]
    # @param entries [Hash<String, Object>, nil]
    # @param root [Boolean]
    # @param umask [Integer, nil]
    # @param writeable [Boolean]
    def initialize name, umask: nil, entries: nil, root: false, writeable: false, &blk
      super(name, umask:)
      @is_root = root
      @writeable = writeable
      @entries = Hash[(entries || {}).
                      collect { [ _1, make_entry(_1, _2) ]}]
      @entry_generator = blk
    end

    def info_hash
      super.merge!({writeable: writeable?,
                     dynamic: @entry_generator != nil})
    end

    def statfs
      ents = entries
      size = ents.sum(&:size)
      {
        type: 0x01021997, # V9FS magic
        bsize: 4096,
        blocks: size / 4096,
        bfree: 0,
        bavail: 0,
        files: ents.size,
        ffree: 0,
        fsid: 0,
        namelen: 255,
        frsize: 0,
        flags: 0
      }
    end

    def make_entry name, data
      case data
      when Entry then data.tap { _1.umask = umask }
      when String then (data.frozen? ? StaticEntry : BufferEntry).new(name, data, umask: umask)
      when Pathname then PathEntry.new(name, data, umask: umask)
      when Hash then DirectoryEntry.new(name, entries: data, umask: umask)
      else StaticEntry.new(name, data, umask: umask)
      end
    end
    
    # @return [Hash<String, Entry>]
    def entries
      ents = @entries
      ents = ents.merge(Hash[@entry_generator.call]) if @entry_generator
      ents
    end

    # @return [Boolean]
    def writeable?
      !!@writeable
    end
    
    # @return [Boolean]
    def is_root?
      !!@is_root
    end

    # @return [Qid]
    def qid
      @qid ||= NonoP::Qid.new(type: is_root? ? NonoP::Qid::Types[:MOUNT] : NonoP::Qid::Types[:DIR],
                              version: 0,
                              path: [ hash ].pack('Q'))
    end
    
    # @return [Boolean]
    def directory?
      true
    end

    # @param p9_mode [NonoP::BitField::Instance]
    # @return [OpenedEntry]
    # @raise SystemCallError
    def open p9_mode
      super(p9_mode, DataProvider.new(self))
    end

    # @return [Integer]
    def size
      entries.size
    end

    # @param count [Integer]
    # @param offset [Integer]
    # @return [Array<Dirent>]
    # @raise SystemCallError
    def readdir count, offset = 0
      entries.values[offset, count] || [] # todo cache in the DataProvider?
    end

    # @return [Hash<Symbol, Object>]
    # @raise SystemCallError
    def getattr
      ents = entries
      NonoP::Server::FileSystem::DEFAULT_DIR_ATTRS.
        merge(qid: qid,
              size: ents.size,
              mode: NonoP::PermMode.new(writeable? ? :RWX : :RX).mask!(~umask) | :DIR,
              blocks: ents.empty?? 0 : (1 + ents.size / NonoP::Server::FileSystem::BLOCK_SIZE))
    end

    # @param name [String]
    # @param flags [Integer]
    # @param mode [Integer]
    # @param gid [Integer]
    # @return [OpenedEntry]
    def create name, flags, mode, gid
      raise Errno::ENOTSUP unless writeable?
      ent = entries[name] = BufferEntry.new(name, '', umask: umask)
      attrs = {}
      attrs[:gid] = gid if gid
      attrs[:mode] = NonoP::PermMode.new(mode).mask!(~umask) | :FILE if mode
      ent.setattr(attrs) unless attrs.empty?
      NonoP.vputs { "Create #{name} #{mode}" }
      ent.open(flags)
    end
  end
end
