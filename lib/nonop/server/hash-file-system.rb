require 'pathname'

require 'sg/ext'
using SG::Ext

require_relative 'file-system'
require_relative '../remote-path'

module NonoP::Server
  class HashFileSystem < FileSystem::Base
    # @return [DirectoryEntry]
    attr_reader :root
    delegate :qid, :entries, to: :root

    # @return [Hash<Integer, FSID>]
    attr_reader :fsids

    # @param root [DirectoryEntry, PathEntry, nil]
    # @param entries [Hash<String, Object>, nil]
    # @param umask [Integer, nil]
    # @param writeable [Boolean]
    def initialize name, root: nil, entries: nil, umask: nil, writeable: false
      super(name)
      @root = root || FileSystem::DirectoryEntry.
        new(name,
            entries: entries,
            umask: umask,
            root: true,
            writeable: writeable)
      @next_id = 0
      @fsids = {}
    end

    def info_hash
      super.merge!(root: @root.info_hash)
    end
    
    # @param path [Array<String>, RemotePath]
    # @return [Qid]
    def qid_for path
      steps, entry = find_entry(path)
      raise KeyError.new("#{path} not found") unless entry
      entry.qid
    end

    # @param fsid [Integer]
    # @param flags [NonoP::BitField::Instance]
    # @return [Integer]
    def open fsid, flags
      NonoP.vputs { "Open #{fsid} #{fsids[fsid]}" }
      id_data = fsids.fetch(fsid)
      id_data.open(flags)
      fsid
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @return [self]
    def close fsid
      id_data = fsids.delete(fsid)
      id_data&.close
      self
    end

    # @param fsid [Integer]
    # @param name [String]
    # @param flags [NonoP::BitField::Instance]
    # @param mode [NonoP::BitField::Instance]
    # @param gid [Integer]
    # @return [Integer]
    def create fsid, name, flags, mode, gid
      id_data = fsids.fetch(fsid)
      id_data.create(name, flags, mode, gid)
      fsid
    rescue KeyError
      raise Errno::EBADFD
    end

    # @return [Integer]
    def next_id
      @next_id += 1
    end

    # @param fsid [Integer]
    # @return [RemotePath]
    def fsid_qid fsid
      fsids.fetch(fsid).qid
    end

    # @param fsid [Integer]
    # @return [RemotePath]
    def fsid_path fsid
      fsids.fetch(fsid).path
    end

    # @param path [String, Array<String>, RemotePath]
    # @param old_fsid [Integer, nil]
    # @return [Array(Array<Qid>, Integer)]
    # @raise SystemCallError
    # @raise KeyError
    def walk path, old_fsid = nil
      path = RemotePath.new(path) if String === path
      i = next_id
      NonoP.vputs { "Walking #{i} to #{path} #{old_fsid}" }
      if path&.empty? && old_fsid && fsids.has_key?(old_fsid)
        fsids[i] = fsids[old_fsid].dup
        [ [], i ]
      else
        steps, entry = find_entry(path,
                                  old_fsid != nil && old_fsid != 0 ?
                                    fsids.fetch(old_fsid).entry : nil)
        fsids[i] = if entry
                     FileSystem::FSID.new(path, entry)
                   else
                     FileSystem::FSID.new(path, steps.last || root)
                   end
        [ steps.collect(&:qid), i ]
      end
    end

    # @param path [String, Array<String>, RemotePath]
    # @param dir [Entry, nil]
    # @return [Array(Array<Qid>, Entry)]
    def find_entry path, dir = nil
      return find_entry(RemotePath.new(path), dir) if String === path
      
      parts = []
      head = nil
      rest = path
      dir ||= root

      while dir && !rest.empty?
        head, rest = rest.split_at(1)
        head = head.first
        ent = dir.entries[head]
        parts << ent if ent
        dir = ent
      end

      return [ parts, dir ]
    end

    # @param fsid [Integer]
    # @param count [Integer]
    # @param offset [Integer]
    # @return [Array<Entry>]
    # @raise SystemCallError
    # @raise KeyError
    def readdir fsid, count, offset = 0
      id_data = fsids.fetch(fsid)
      NonoP.vputs { "readdir #{fsid} #{id_data.open_flags}" }
      raise Errno::EACCES unless id_data.reading?
      id_data.readdir(count, offset)
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @param count [Integer]
    # @param offset [Integer]
    # @return [String]
    # @raise SystemCallError
    # @raise KeyError
    def read fsid, count, offset = 0, &cb
      id_data = fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.reading?
      id_data.read(count, offset, &cb)
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @param data [String]
    # @param offset [Integer]
    # @yield [count]
    # @yieldparam count [Integer]
    # @return [Integer, void]
    # @raise SystemCallError
    # @raise KeyError
    def write fsid, data, offset = 0, &cb
      id_data = fsids.fetch(fsid)
      raise Errno::EACCES unless id_data.writing?
      id_data.write(data, offset, &cb)
    rescue KeyError
      raise Errno::EBADFD
    end

    # @param fsid [Integer]
    # @return [Hash<Symbol, Object>]
    # @raise SystemCallError
    # @raise KeyError
    def getattr fsid
      NonoP.vputs { "GetAttr #{fsid} #{fsids.has_key?(fsid)}" }
      fsids.fetch(fsid).getattr
    rescue KeyError
      if fsid == 0
        root.getattr
      else
        raise Errno::EBADFD
      end
    end

    # @param fsid [Integer]
    # @param attrs [Hash<Symbol, Object>]
    # @return [self]
    # @raise SystemCallError
    # @raise KeyError
    def setattr fsid, attrs
      NonoP.vputs { "SetAttr #{fsid} #{fsids[fsid].inspect}" }
      fsids.fetch(fsid).setattr(attrs)
      self
    rescue KeyError
      raise Errno::EBADFD
    end

    # @abstract
    # @return [Hash(Symbol, Obkect)]
    def statfs
      NonoP.vputs { "HFS statfs: #{root.class}" }
      root.statfs
    end
  end
end
