require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NonoP::Server
  class AuthStream < Stream
    attr_reader :environment
    attr_reader :uname
    attr_reader :uid
    attr_reader :aname
    attr_reader :remote_address
    attr_reader :data
    attr_reader :user
    
    def initialize environment, pkt = nil, uname: nil, uid: nil, aname: nil, data: nil, remote_address: nil
      @environment = environment
      @uname = uname || pkt&.uname&.to_s
      @uname = nil if @uname.blank?
      @uid = uid || pkt&.n_uname
      @aname = aname || pkt&.aname&.to_s
      @remote_address = remote_address
      @data = data || ''
    end

    def qid
      @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:AUTH],
                              version: 0,
                              path: [ hash ].pack('Q'))
    end

    def write data, offset = 0, &cb
      raise EOFError.new if closed?
      @data[offset, data.size] = data
      NonoP.maybe_call(cb, data.size)
    end

    def authenticate(...)
      @user || authentic?(...)
    end
    
    def authentic? uname = nil, uid = nil, credentials: nil, aname: nil
      NonoP.vputs {
        addr = begin
                 remote_address.ip_address
               rescue
                 '---'
               end
        [ "Authenticating #{addr} #{uname}/#{@uname} #{aname}/#{@aname} #{uid}/#{@uid}", (credentials || @data).inspect, @environment.find_user(@uid).inspect ]
      }
      matches = (uname.blank? || @uname == uname) &&
        (uid.blank? || @uid == uid) &&
        (aname.blank? || @aname == aname)
      return false unless matches
      
      @user = @environment.
        authenticate(remote_address: @remote_address,
                     uname: uname.blank?? @uname : uname,
                     uid: uid || @uid,
                     credentials: credentials.blank?? @data : credentials)
      @data.clear
      @user
    end

    def dup
      self.class.new(environment, aname: @aname,
                     uname: @uname, uid: @uid,
                     remote_address: remote_address,
                     data: @data)
    end
  end
end
