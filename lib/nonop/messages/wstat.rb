require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NonoP
  # See https://inferno-os.org/inferno/man/5/stat.html
  class Twstat
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:size, :uint16l],
                   [:type, :uint16l],
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

  class Rwstat
    include Packet::Data
    define_packing([:fid, :uint32l])
  end
end
