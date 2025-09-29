require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NonoP
  module L2000
    class Tstatfs
      include Packet::Data
      define_packing([:fid, :uint32l])
    end

    class Rstatfs
      include Packet::Data
      define_packing([:type, :uint32l],
                     [:bsize, :uint32l],
                     [:blocks, :uint64l],
                     [:bfree, :uint64l],
                     [:bavail, :uint64l],
                     [:files, :uint64l],
                     [:ffree, :uint64l],
                     [:fsid, :uint64l],
                     [:namelen, :uint32l],)
    end
  end
end
