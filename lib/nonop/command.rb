require 'sg/ext'
using SG::Ext

require 'socket'
require 'munge'
require 'optparse'

module NonoP
  module Command
    class Base
      attr_reader :protocol, :buffer_size
      attr_reader :desc, :arguments
      
      def initialize
        @desc = 'A command.'
        @protocol = nil
        @buffer_size = 4096
      end
      
      def opts
        OptionParser.new do |o|
          o.banner += "\n\n" + desc + "\n\n"
          o.on('-H', '--help-banner') do
            puts(desc)
            exit(0)
          end
          o.on('-v', '--verbose') do
            $verbose = true
          end
          o.on('-P', '--protocol NAWE') do |v|
            @protocol = v
          end
          o.on('--buffer-size BYTES', Integer) do |v|
            @buffer_size = v
          end
        end
      end

      def parse_opts args
        @arguments = opts.parse(args)
      end
      
      def run args
        parse_opts(args)
      end
    end
    
    class Client < Base
      attr_reader :host, :port, :uid, :uname, :auth_creds
      attr_reader :desc, :client
      
      def initialize
        super
        @desc = 'A command.'
        @host = 'localhost'
        @port = 564
        @uid = Process.uid
        @uname = ENV['USER']
        @auth_creds = nil
      end
      
      def opts
        super.tap do |o|
          o.on('--host HOST') do |v|
            @host = v
          end
          o.on('-p', '--port INTEGER', Integer) do |v|
            @port = v
          end
          o.on('-u', '--uname NAME') do |v|
            @uname = v
          end
          o.on('--uid INTEGER', Integer) do |v|
            @uid = v.to_i
            @uid = nil if @uid < 0
          end
          o.on('--auth-creds CREDS') do |v|
            @auth_creds = v
          end
          o.on('-n', '--no-auth') do
            @auth_creds = false
          end
        end
      end

      def closed?
        client == nil || client.closed?
      end

      def close
        client.close
      end
      
      def connect
        return self unless closed?
        make_client
        client.start

        if uid && auth_creds != false
          @auth_creds ||= Munge.encode(uid: uid) # todo auth provider
          client.auth(uname: uname,
                      aname: aname,
                      n_uname: uid,
                      credentials: auth_creds)
        end
        self
      end

      def make_client
        sock = TCPSocket.new(host, port)
        coder = NonoP.coder_for(protocol)
        @client = NonoP::Client.new(coder: coder, io: sock)
      end

      def run args, &blk
        super
        connect

        %w{INT QUIT}.each do |sig|
          Signal.trap(sig) do
            NonoP.vputs("Caught #{sig}")
            self.close
          end
        end

        blk&.call
        client.read_loop
        true
      end
    end
  end
end
