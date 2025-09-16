require 'sg/ext'
using SG::Ext

require 'sg/attr_struct'

require_relative 'packet'
require_relative 'messages/error'
require_relative 'messages/version'
require_relative 'messages/attach'
require_relative 'messages/auth'
require_relative 'messages/walk'
require_relative 'messages/clunk'
require_relative 'messages/remove'
require_relative 'messages/stat'
require_relative 'messages/read'

require_relative 'messages/2000L/error'
require_relative 'messages/2000L/auth'
require_relative 'messages/2000L/attach'
require_relative 'messages/2000L/open'
require_relative 'messages/2000L/readdir'
require_relative 'messages/2000L/getattr'

module NineP
  class Decoder
    MAX_MSGLEN = 65535
    RequestReplies = [ [ Tversion, Rversion ],
                       [ Tattach, Rattach ],
                       [ nil, Rerror ],
                       [ Tauth, Rauth ],
                       [ Tclunk, Rclunk ],
                       [ Twalk, Rwalk ],
                       [ Tremove, Rremove ],
                       [ Tstat, Rstat ],
                       [ Tread, Rread ],
                     ]

    class DecodeError < RuntimeError
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
    
    attr_reader :packet_types
    attr_accessor :max_msglen
    
    def initialize coders: nil, max_msglen: nil
      @max_msglen = max_msglen || MAX_MSGLEN
      @packet_types = Hash.new(NopDecoder)
      add_packet_types(coders) unless coders&.empty?
    end

    def version
      '9P2000.L'
    end
    
    def max_datalen
      max_msglen - 7 # Packet.attribute_offset(:raw_data)
    end
    
    class NopDecoder
      def self.unpack str
        [ nil, str ]
      end
    end

    def send_one pkt, io
      data = pkt.pack
      io.write(data)
    end
    
    def read_one io
      # todo any real need for Packet? Which of these is faster?
      pkt, more = Packet.read(io)
      raise DecodeError.new(-1, pkt, more) unless more.blank?
      pkt.coder = packet_types[pkt.type]
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
  end

  module L2000
    class Decoder < NineP::Decoder
      RequestReply = [ [ Tversion, Rversion ],
                       [ Tattach, Rattach ],
                       [ nil, NineP::Rerror ],
                       [ nil, L2000::Rerror ],
                       [ Tauth, Rauth ],
                       [ Tclunk, Rclunk ],
                       [ Twalk, Rwalk ],
                       [ Tread, Rread ],
                       [ Tremove, Rremove ],
                       [ Tstat, Rstat ],
                       [ Topen, Ropen ],
                       [ Treaddir, Rreaddir ],
                       [ Tgetattr, Rgetattr]
                     ]
      def initialize **opts
        super(**opts.merge(coders: RequestReply.flatten.reject(&:nil?)))
      end
    end
  end
end
