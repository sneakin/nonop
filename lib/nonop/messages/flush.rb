require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NonoP
  class Tflush
    include Packet::Data
    define_packing([:oldtag, :uint16l])
  end

  class Rflush
    include Packet::Data
    define_packing()
  end
end
