require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NineP
  class Qid
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:type, :uint8],
                   [:version, :uint32l],
                   [:path, :string, 8])
  end
end
