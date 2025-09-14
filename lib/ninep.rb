require 'sg/packed_struct'

# todo have each type only handle @data?
# todo much much; only decodes a failed mount

require 'sg/ext'
using SG::Ext

module NineP
  class Packet
    module Data
      def self.included base
        base.include SG::AttrStruct
        base.include SG::PackedStruct
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def type_id
          self.const_get('ID')
        end
      end

      def type_id
        self.class.type_id
      end
    end
    
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:size, :uint32l],
                   [:type, :uint8],
                   [:tag, :uint16l],
                   [:raw_data, :string, :data_size])
    
    attributes :coder, :data, :extra_data
    
    def size
      @size || (attribute_offset(:raw_data) + data.bytesize)
    end

    def coder
      @coder || data&.class
    end
        
    def type
      @type || coder.type_id
    end
    
    def pack
      @raw_data = @data.pack if @data
      super
    end
        
    def data_size
      size - attribute_offset(:raw_data)
    end

    def data
      return @data if @data
      @data, @extra_data = coder.unpack(@raw_data)
      @data
    end
  end
  
  class Decoder
    class DecodeError < RuntimeError
      include SG::AttrStruct
      attributes :size, :packet, :extra
      
      def message
        "Decode error: read #{size} bytes, #{packet.class} left #{extra&.bytesize || 0} bytes."
      end
    end
    
    attr_reader :packet_types
    
    def initialize coders: nil
      @packet_types = Hash.new(NopDecoder)
      add_packet_types(coders) unless coders&.empty?
    end
    
    class NopDecoder
      def self.unpack str
        [ nil, str ]
      end
    end

    def send_one pkt, io
      data = pkt.pack
      $stderr.puts("> %s %s" % [ pkt.data.class.name, data.inspect ]) if $verbose
      io.write(data)
    end
    
    def read_one io    
      pktsize = io.read(4)
      len = pktsize.unpack('L<').first
      $stderr.write("< #{len} ") if $verbose
      data = io.read(len - 4)
      $stderr.write(data.inspect) if $verbose
      pkt, more = unpack(pktsize + data)
      raise DecodeError.new(len, pkt, more) unless more.empty?
      pkt
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

  class NString
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:size, :uint16l],
                   [:value, :string, :size])

    def initialize *opts
      case opts
        in [] then @size = 0
        in [ Integer, String ] then @size, @value = opts
        in [ Integer ] then @size = opts[0]
        in [ Hash ] then @size, @value = opts[0].pick(:size, :value)
        in [ String ] then @size, @value = [ opts[0].size, opts[0] ]
      end
      @value ||= "\x00" * @size
    end
        
    def size
      @size || value.size
    end
    
    def to_s
      value
    end
  end

  class Qid
    include SG::AttrStruct
    include SG::PackedStruct
    define_packing([:type, :uint8],
                   [:version, :uint32l],
                   [:path, :string, 8])
  end
      
  class Tversion
    ID = 100
    include Packet::Data
    define_packing([:msize, :uint32l],
                   [:version, NString])
  end

  class Rversion < Tversion
    ID = 101
  end

  class Tattach
    ID = 104
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:afid, :uint32l],
                   [:uname, NString],
                   [:aname, NString])
  end

  class Rattach
    ID = 105
    include Packet::Data
    define_packing([:aqid, Qid])
  end

  class Rerror
    ID = 7
    include Packet::Data
    define_packing([:code, :uint32l])
  end
  
  class Tauth
    ID = 102
    include Packet::Data
    define_packing([:afid, :uint32l],
                   [:uname, NString],
                   [:aname, NString])
  end
  
  class Rauth
    ID = 103
    include Packet::Data
    define_packing([:aqid, Qid])
  end

  class Tclunk
    ID = 120
    include Packet::Data
    define_packing([:fid, :uint32l])
  end

  class Rclunk
    ID = 121
    include Packet::Data
    define_packing()
  end

  class Twalk
    # size[4] Twalk tag[2] fid[4] newfid[4] nwname[2] nwname*(wname[s])
    ID = 110
    include Packet::Data
    define_packing([:fid, :uint32l],
                   [:newfid, :uint32l],
                   [:nwnames, :uint16l],
                   [:wnames, NString, :nwnames])
    
    def pack
      self.nwnames = wnames.size
      super
    end
  end

  class Rwalk
    # size[4] Rwalk tag[2] nwqid[2] nwqid*(wqid[13])
    ID = 111
    include Packet::Data
    define_packing([:nwqid, :uint16l],
                   [:wqid, Qid, :nwqid])
    
    def pack
      self.nwqid = wqid.size
      super
    end
  end

  RequestReplies = [ [ Tversion, Rversion ],
                     [ Tattach, Rattach ],
                     [ nil, Rerror ],
                     [ Tauth, Rauth ],
                     [ Tclunk, Rclunk ],
                     [ Twalk, Rwalk ] ]
                     
  class Client
    def initialize coder:, io:
      @coder = coder
      @io = io
    end
    
    def read_one
      @coder.read_one(@io)
    end
    
    def send_one pkt
      @coder.send_one(pkt, @io)
    end
    
    def flush
      @io.flush
    end
    
    def close
      @io.close
    end
    
    def closed?
      @io.closed?
    end
  end

  module L2000
    class Tauth
      ID = 102
      include Packet::Data
      define_packing([:afid, :uint32l],
                     [:uname, NString],
                     [:aname, NString],
                     [:n_uname, :uint32l]) # 9p2000.L only
    end
  
    class Tattach
      ID = 104
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:afid, :uint32l],
                     [:uname, NString],
                     [:aname, NString],
                     [:n_uname, :uint32l])
    end

    class Topen
      # size[4] Tlopen tag[2] fid[4] flags[4]
      ID = 12
      include Packet::Data
      define_packing([:fid, :uint32l],
                     [:flags, :uint32l])
    end

    class Ropen
      # size[4] Rlopen tag[2] qid[13] iounit[4]
      ID = 13
      include Packet::Data
      define_packing([:qid, Qid],
                     [:iounit, :uint32l])
    end

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

    class Decoder < NineP::Decoder
      RequestReply = [ [ Tversion, Rversion ],
                       [ Tattach, Rattach ],
                       [ nil, Rerror ],
                       [ Tauth, Rauth ],
                       [ Tclunk, Rclunk ],
                       [ Twalk, Rwalk ],
                       [ Topen, Ropen ],
                       [ Treaddir, Rreaddir ] ]
      def initialize
        super(coders: RequestReply.flatten.reject(&:nil?))
      end
    end
  end
end
