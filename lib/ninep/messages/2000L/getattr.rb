require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'
require_relative '../../time_t'

module NineP
  module L2000
    class Tgetattr
      Flags = {
        BASIC:        0x000007ff,
        ALL:          0x00003fff,
        MODE:         0x00000001,
        NLINK:        0x00000002,
        UID:          0x00000004,
        GID:          0x00000008,
        RDEV:         0x00000010,
        ATIME:        0x00000020,
        MTIME:        0x00000040,
        CTIME:        0x00000080,
        INO:          0x00000100,
        SIZE:         0x00000200,
        BLOCKS:       0x00000400,
        BTIME:        0x00000800,
        GEN:          0x00001000,
        DATA_VERSION: 0x00002000,
      }
      
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:request_mask, :uint64l])
      init_attr :request_mask, Flags[:ALL]
    end

    class Rgetattr
      include Packet::Data
      define_packing([ :valid, :uint64l ],
                     [ :qid, Qid ],
                     [ :mode, :uint32l ],
                     [ :uid, :uint32l ],
                     [ :gid, :uint32l ],
                     [ :nlink, :uint64l ],
                     [ :rdev, :uint64l ],
                     [ :size, :uint64l ],
                     [ :blksize, :uint64l ],
                     [ :blocks, :uint64l ],
                     [ :atime_sec, TimeT ],
                     [ :atime_nsec, :uint64l ],
                     [ :mtime_sec, TimeT ],
                     [ :mtime_nsec, :uint64l ],
                     [ :ctime_sec, TimeT ],
                     [ :ctime_nsec, :uint64l ],
                     [ :btime_sec, TimeT ],
                     [ :btime_nsec, :uint64l ],
                     [ :gen, :uint64l ],
                     [ :data_version, :uint64l ])
      def atime_sec= t
        key = Integer === t ? :n : :t
        @atime_sec = TimeT.new(key => t)
      end
      def mtime_sec= t
        key = Integer === t ? :n : :t
        @mtime_sec = TimeT.new(key => t)
      end
      def ctime_sec= t
        key = Integer === t ? :n : :t
        @ctime_sec = TimeT.new(key => t)
      end
      def btime_sec= t
        key = Integer === t ? :n : :t
        @btime_sec = TimeT.new(key => t)
      end
    end
  end
end
