require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NineP
  class Tstat
    include Packet::Data
    define_packing([:fid, :uint32l])
  end

  class Rstat
    include Packet::Data
    define_packing([:size, :uint16l],
                   [:type, :uint32l],
                   [:dev, :uint32l],
                   [:qid, Qid],
                   [:mode, :uint32l],
                   [:atime, :uint32l],
                   [:mtime, :uint32l],
                   [:length, :uint64l],
                   [:name, NString],
                   [:uid, NString],
                   [:gid, NString],
                   [:muid, NString])
  end
end
