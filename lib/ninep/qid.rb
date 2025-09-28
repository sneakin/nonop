require 'sg/ext'
using SG::Ext

require 'sg/packed_struct'

module NineP
  class Qid
    Types = {
      DIR: 0x80,
      APPEND: 0x40,
      EXCL: 0x20,
      MOUNT: 0x10,
      AUTH: 0x08,
      TMP: 0x04,
      SYMLINK: 0x02,
      LINK: 0x01,
      FILE: 0x00,
    }

    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:type, :uint8],
                   [:version, :uint32l],
                   [:path, :string, 8])
  end
end
