require 'sg/ext'
using SG::Ext

require_relative 'packet-data'

module NonoP
  module ErrorPayload
    attr_reader :code

    def code= v
      @code = case v
              when NonoP::Error then v.code
              when SystemCallError then v.errno
              when Class then v.const_get('Errno')
              else v
              end
    end
  end

  def self.maybe_wrap_error pkt, error = Error, msg: nil
    case pkt
    when ErrorPayload then error.new(pkt, msg)
    else pkt
    end
  end

  class Rerror
    include ErrorPayload
    include Packet::Data
    define_packing([:msg, NString],
                   [:code, :uint32l])
  end
end
