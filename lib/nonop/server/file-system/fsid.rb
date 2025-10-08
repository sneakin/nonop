require 'sg/ext'
using SG::Ext

module NonoP::Server::FileSystem
  # Provides the operations for ~fsid~ numbers to reference an OpenedEntry.
  class FSID
    # @return [RemotePath]
    attr_accessor :path
    # @return [Entry]
    attr_accessor :entry
    # @return [OpenedEntry, nil]
    attr_accessor :backend
    # @return [Integer, nil]
    attr_accessor :open_flags

    # @param path [RemotePath]
    # @param entry [Entry]
    # @param open_flags [Integer, nil]
    # @param backend [OpenedEntry, nil]
    def initialize path, entry, open_flags: nil, backend: nil
      @path = path
      @entry = entry
      @open_flags = NonoP::OpenFlags.new(open_flags)
      @backend = backend
    end

    # @return [FSID]
    def dup
      self.class.new(path, entry, open_flags:, backend: backend.dup)
    end

    # @return [Boolean]
    def reading?
      (0 == (open_flags.mask(NonoP::OpenFlags[:MODE])) ||
       (open_flags & :RDWR))
    end

    # @return [Boolean]
    def writing?
      (open_flags & [ :WRONLY, :RDWR, :APPEND ])
    end

    # @param flags [NonoP::BitField::Instance]
    # @return [self]
    def open flags
      @open_flags = flags
      backend&.close
      @backend = entry.open(flags)
      self
    end

    # @return [self]
    def close
      backend&.close
      @backend = nil
      self
    end

    # @param name [String]
    # @param flags [Integer]
    # @param mode [Integer]
    # @param gid [Integer]
    # @return [self]
    def create name, flags, mode, gid
      @open_flags = flags
      backend&.close
      @backend = entry.create(name, flags, mode, gid)
      self
    end

    delegate :truncate, :read, :write, :readdir, to: :backend
    delegate :qid, :size, :getattr, :setattr, to: :entry
  end
end
