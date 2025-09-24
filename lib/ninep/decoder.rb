require 'sg/ext'
using SG::Ext

require 'sg/attr_struct'

require_relative 'util'
require_relative 'errors'

require_relative 'packet'
require_relative 'messages/error'
require_relative 'messages/version'
require_relative 'messages/attach'
require_relative 'messages/auth'
require_relative 'messages/walk'
require_relative 'messages/clunk'
require_relative 'messages/remove'
require_relative 'messages/stat'
require_relative 'messages/wstat'
require_relative 'messages/create'
require_relative 'messages/open'
require_relative 'messages/read'
require_relative 'messages/write'
require_relative 'messages/flush'

require_relative 'messages/2000L/error'
require_relative 'messages/2000L/auth'
require_relative 'messages/2000L/attach'
require_relative 'messages/2000L/open'
require_relative 'messages/2000L/create'
require_relative 'messages/2000L/readdir'
require_relative 'messages/2000L/getattr'
require_relative 'messages/2000L/setattr'
require_relative 'messages/2000L/statfs'
require_relative 'messages/2000L/symlink'
require_relative 'messages/2000L/readlink'
require_relative 'messages/2000L/mknod'
require_relative 'messages/2000L/mkdir'
require_relative 'messages/2000L/link'
require_relative 'messages/2000L/rename'

module NineP
  class Decoder
    VERSION = '9P2000'
    
    MIN_MSGLEN = 128
    MAX_MSGLEN = 65535

    RequestReplies = {
      7 => L2000::Rerror,
      100 => Tversion, 101 => Rversion,
      102 => Tauth, 103 => Rauth,
      104 => Tattach, 105 => Rattach,
      107 => Rerror,
      108 => Tflush, 109 => Rflush,
      110 => Twalk, 111 => Rwalk,
      112 => Topen, 113 => Ropen,
      114 => Tcreate, 115 => Rcreate,
      116 => Tread, 117 => Rread,
      118 => Twrite, 119 => Rwrite,
      120 => Tclunk, 121 => Rclunk,
      122 => Tremove, 123 => Rremove,
      124 => Tstat, 125 => Rstat,
      126 => Twstat, 127 => Rwstat,
    }

    class DecodeError < NineP::Error
      include SG::AttrStruct
      attributes :size, :packet, :extra
      
      def message
        "Decode error: read #{size} bytes, #{packet.class} left #{extra&.bytesize || 0} bytes."
      end
    end
    
    class InvalidSize < RuntimeError
      include SG::AttrStruct
      attributes :size, :max_msglen
      
      def message
        "Decode error: #{size || '---'} is not between 0 and #{max_msglen || '---'}"
      end
    end

    attr_reader :version, :packet_types, :packet_types_inv
    attr_accessor :max_msglen
    
    def initialize coders: nil, version: nil, max_msglen: nil
      raise ArgumentError.new("max_msglen must be > #{MIN_MSGLEN}") if max_msglen && max_msglen <= MIN_MSGLEN
      @version = version || VERSION
      @max_msglen = max_msglen || MAX_MSGLEN
      @packet_types = Hash.new(NopDecoder)
      @packet_types_inv = Hash.new(NopDecoder)
      add_packet_types(coders || RequestReplies)
    end

    def max_datalen
      max_msglen - MIN_MSGLEN # Packet.attribute_offset(:raw_data)
    end
    
    class NopDecoder
      def self.unpack str
        [ nil, str ]
      end
    end

    def send_one pkt, io
      pkt.type = @packet_types_inv[pkt.coder]
      NineP.vputs { "<< %s %i %s" % [ pkt.type, pkt.size, pkt.inspect ] }
      data = pkt.pack
      NineP.vputs { "   %s %i %s" % [ pkt.coder, data.size, data.inspect ] }
      io.write(data)
    end
    
    def read_one io
      # todo any real need for Packet? Which of these is faster?
      pkt, more = begin
        Packet.read(io)
      rescue ArgumentError
        raise DecodeError.new(-1, nil, nil)
      end
      pkt.coder = packet_types[pkt.type]
      NineP.vputs { ">> %s %s %s" % [ pkt.tag, pkt.type, pkt.data.inspect ] }
      raise DecodeError.new(-1, pkt, more) if NopDecoder === pkt.coder || !more.blank?
      pkt

      # pktsize = io.read(4)
      # len = pktsize.unpack('L<').first
      # raise InvalidSize.new(len, max_msglen) if len === 0..max_msglen # todo off by 1?
      # $stderr.write("< #{len} ") if $verbose
      # data = io.read(len - 4)
      # $stderr.write(data.inspect) if $verbose
      # pkt, more = unpack(pktsize + data)
      # raise DecodeError.new(len, pkt, more) unless more.blank?
      # pkt
    end

    def unpack str
      pkt, more = Packet.unpack(str)
      pkt.coder = packet_types[pkt.type]
      [ pkt, more ]
    end
    
    def add_packet_type id, packer
      packet_types[id] = packer
      packet_types_inv[packer] = id
      self
    end
    
    def add_packet_types types
      types.each do
        case _1
        when Class then add_packet_type(_1.const_get('ID'), _1)
        when Integer then add_packet_type(_1, _2)
        else raise ArgumentError, types
        end
      end
      self
    end

    def type_id_for klass
      @packet_types_inv[klass]
    end
  end

  module L2000
    class Decoder < NineP::Decoder
      VERSION = '9P2000.L'
      
      RequestReplies = {
        7 => L2000::Rerror,
        8 => Tstatfs, 9 => Rstatfs,
        12 => L2000::Topen, 13 => L2000::Ropen,
        14 => L2000::Tcreate, 15 => L2000::Rcreate,
        16 => Tsymlink, 17 => Rsymlink,
        18 => Tmknod, 19 => Rmknod,
        20 => Trename, 21 => Rrename,
        22 => Treadlink, 23 => Rreadlink,
        24 => Tgetattr, 25 => Rgetattr,
        26 => Tsetattr, 27 => Rsetattr,
        40 => Treaddir, 41 => Rreaddir,
        70 => Tlink, 71 => Rlink,
        72 => Tmkdir, 73 => Rmkdir,
        102 => L2000::Tauth, 103 => L2000::Rauth,
        104 => L2000::Tattach, 105 => L2000::Rattach,
      }

      def initialize **opts
        super(**opts.merge(coders: NineP::Decoder::RequestReplies.merge(RequestReplies),
                           version: VERSION))
      end
    end
  end

  Coders = {
    '9P' => Decoder,
    Decoder::VERSION => Decoder,
    L2000::Decoder::VERSION => L2000::Decoder
  }

  def self.coder_for name, **opts
    Coders.fetch(name || L2000::Decoder::VERSION).new(**opts)
  end
end
