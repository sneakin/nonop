require 'sg/ext'
using SG::Ext

require 'nonop/remote-path'
require 'nonop/perm-mode'

module NonoP::Server
  module FileSystem
    BLOCK_SIZE = 4096

    DEFAULT_DIR_ATTRS = {
      valid: 0xFFFF, # mask of set fields
      mode: NonoP::PermMode[:DIR] | NonoP::PermMode[:RWX],
      uid: Process.uid,
      gid: Process.gid,
      nlink: 1,
      rdev: 0,
      blksize: BLOCK_SIZE,
      atime_sec: Time.now,
      atime_nsec: 0,
      mtime_sec: Time.now,
      mtime_nsec: 0,
      ctime_sec: Time.now,
      ctime_nsec: 0,
      btime_sec: Time.now,
      btime_nsec: 0,
      gen: 0,
      data_version: 0
    }

    DEFAULT_FILE_ATTRS = DEFAULT_DIR_ATTRS.
      merge(mode: NonoP::PermMode[:FILE] | NonoP::PermMode[:R])

    autoload :Entry, 'nonop/server/file-system/entry'
    autoload :OpenedEntry, 'nonop/server/file-system/opened-entry'
    autoload :FSID, 'nonop/server/file-system/fsid'
    autoload :Base, 'nonop/server/file-system/base'
    autoload :StaticEntry, 'nonop/server/file-system/static-entry'
    autoload :BufferEntry, 'nonop/server/file-system/buffer-entry'
    autoload :WriteableEntry, 'nonop/server/file-system/writeable-entry'
    autoload :FifoEntry, 'nonop/server/file-system/fifo-entry'
    autoload :PathEntry, 'nonop/server/file-system/path-entry'
    autoload :DirectoryEntry, 'nonop/server/file-system/directory-entry'
  end
end
