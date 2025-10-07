require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'

module NonoP
  module L2000
    class Tcreate
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:name, NString ],
                     [:nflags, :uint32l],
                     [:mode, :uint32l],
                     [:gid, :uint32l])
      attributes :flags
      calc_attr :nflags, lambda { flags.to_i }

      def nflags= v
        @nflags = v
        self.flags = v
      end
      
      def flags= v
        @flags = NonoP::OpenFlags.new(v)
      end
    end

    class Rcreate
      include Packet::Data
      define_packing([:qid, Qid ],
                     [:iounit, :uint32l])
    end
  end
end
