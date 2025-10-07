require 'sg/ext'
using SG::Ext

require_relative '../packet-data'
require_relative '../../qid'
require_relative '../../open-flags'

module NonoP
  module L2000
    class Topen
      # size[4] Tlopen tag[2] fid[4] flags[4]
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:nflags, :uint32l])
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

    class Ropen < NonoP::Ropen
    end
  end
end
