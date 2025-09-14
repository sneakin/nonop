require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Tgetattr
      Flags = {
        BASIC:           0x000007ff,
        ALL:             0x00003fff,
      }
      
      ID = 24
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:request_mask, :uint64l])
      init_attr :request_mask, Flags[:ALL]
    end

    class Rgetattr
      ID = 25
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
                     [ :atime_sec, :uint64l ],
                     [ :atime_nsec, :uint64l ],
                     [ :mtime_sec, :uint64l ],
                     [ :mtime_nsec, :uint64l ],
                     [ :ctime_sec, :uint64l ],
                     [ :ctime_nsec, :uint64l ],
                     [ :btime_sec, :uint64l ],
                     [ :btime_nsec, :uint64l ],
                     [ :gen, :uint64l ],
                     [ :data_version, :uint64l ])
    end
  end
end
