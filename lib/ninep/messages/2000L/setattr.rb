require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tsetattr
      Bits = {
        MODE:      0x00000001,
        UID:       0x00000002,
        GID:       0x00000004,
        SIZE:      0x00000008,
        ATIME:     0x00000010,
        MTIME:     0x00000020,
        CTIME:     0x00000040,
        ATIME_SET: 0x00000080,
        MTIME_SET: 0x00000100,
        ALL:       0x000001FF,
      }

      include Packet::Data
      # size[4] Tsetattr tag[2] fid[4] valid[4] mode[4] uid[4] gid[4] size[8]
      # atime_sec[8] atime_nsec[8] mtime_sec[8] mtime_nsec[8]
      define_packing([:fid, :uint32l],
                     [:valid, :uint32l],
                     [:mode, :uint32l],
                     [:uid, :uint32l],
                     [:gid, :uint32l],
                     [:size, :uint32l],
                     [:atime_sec, :uint64l],
                     [:atime_nsec, :uint64l],
                     [:mtime_sec, :uint64l],
                     [:mtime_nsec, :uint64l])
    end

    class Rsetattr
      include Packet::Data
      # size[4] Rsetattr tag[2]
      define_packing()
    end
  end
end
