require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NonoP::Server
  class AuthStream < Stream
    attr_reader :environment
    attr_reader :user
    attr_reader :uid
    attr_reader :aname
    attr_reader :remote_addr
    attr_reader :data
    
    def initialize environment, pkt = nil, user: nil, uid: nil, aname: nil, data: nil, remote_addr: nil
      @environment = environment
      @user = user || pkt&.uname&.to_s
      @user = nil if @user.blank?
      @uid = uid || pkt&.n_uname
      @aname = aname || pkt&.aname&.to_s
      @remote_addr = remote_addr
      @data = data || ''
    end

    def qid
      @qid ||= NonoP::Qid.new(type: NonoP::Qid::Types[:AUTH],
                              version: 0,
                              path: [ hash ].pack('Q'))
    end

    def write data, offset = 0
      raise EOFError.new if closed?
      @data[offset, data.size] = data
      data.size
    end

    def authentic? uname = nil, uid = nil, data = nil
      NonoP.vputs {
        addr = begin
                 remote_addr.ip_address
               rescue
                 '---'
               end
        [ "Authenticating #{addr} #{@user} #{@aname} #{@uid} #{uname} #{uid}", (data || @data).inspect, @environment.find_user(@uid).inspect ]
      }
      (uname.blank? || @user == uname) &&
        (uid.blank? || @uid == uid) &&
        @environment.authenticate(remote_addr: @remote_addr,
                                  user: uname.blank?? @user : uname,
                                  uid: uid || @uid,
                                  credentials: data || @data)
      # todo clear data?
    end

    def dup
      self.class.new(environment, aname: @aname,
                     user: @user, uid: @uid,
                     data: @data)
    end
  end
end
