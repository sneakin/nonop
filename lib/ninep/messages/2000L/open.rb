require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Topen
      Flags = {
        RDONLY:        00000000,
        WRONLY:        00000001,
        RDWR:          00000002,
        NOACCESS:      00000003,
        CREATE:        00000100,
        EXCL:          00000200,
        NOCTTY:        00000400,
        TRUNC:         00001000,
        APPEND:        00002000,
        NONBLOCK:      00004000,
        DSYNC:         00010000,
        FASYNC:        00020000,
        DIRECT:        00040000,
        LARGEFILE:     00100000,
        DIRECTORY:     00200000,
        NOFOLLOW:      00400000,
        NOATIME:       01000000,
        CLOEXEC:       02000000,
        SYNC:          04000000
      }
      
      # size[4] Tlopen tag[2] fid[4] flags[4]
      ID = 12
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:flags, :uint32l])
    end

    class Ropen
      # size[4] Rlopen tag[2] qid[13] iounit[4]
      ID = 13
      include Packet::Data
      define_packing([:qid, Qid],
                     [:iounit, :uint32l])
    end
  end
end
