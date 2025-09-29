require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NonoP
  module L2000 # todo part of the base 9p?
    DirentTypes = {
      UNKNOWN: 0,
      FIFO:    1,
      CHR:     2,
      DIR:     4,
      BLK:     6,
      REG:     8,
      LNK:     10,
      SOCK:    12,
      WHT:     14
    }

    class Treaddir
      # size[4] Treaddir tag[2] fid[4] offset[8] count[4]
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
      include Packet::Data
      define_packing([:count, :uint32l],
                     [:data, :string, :count])
      attributes :entries

      def unpack_entries
        ents = []
        d = data
        while d != ""
          e, d = Dirent.unpack(d)
          ents << e
        end
        ents
      end

      def entries
        @entries ||= unpack_entries
      end

      def pack
        self.data = entries.collect(&:pack).join
        self.count = self.data.bytesize
        super
      end
    end
  end
end
