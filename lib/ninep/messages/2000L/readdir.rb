require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NineP
  module L2000
    class Treaddir
      # size[4] Treaddir tag[2] fid[4] offset[8] count[4]
      ID = 40
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:offset, :uint64l],
                     [:count, :uint32l])
    end

    class Rreaddir
      class Dirent
        # qid[13] offset[8] type[1] name[s]
        include SG::AttrStruct
        include SG::PackedStruct
        define_packing([:qid, Qid],
                       [:offset, :uint64l],
                       [:type, :uint8],
                       [:name, NString])
      end
      # size[4] Rreaddir tag[2] count[4] data[count]
      ID = 41
      include Packet::Data
      define_packing([:count, :uint32l],
                     [:data, :string, :count])
      
      def entries
        ents = []
        d = data
        while d != ""
          e, d = Dirent.unpack(d)
          ents << e
        end
        ents
      end
    end
  end
end
