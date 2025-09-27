require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NineP::Server
  class AuthStream < Stream
    def initialize environment, user, data = nil
      @environment = environment
      @user = user
      @data = data || ''
    end

    def write data, offset = 0
      raise EOFError.new if closed?
      @data[offset, data.size] = data
      data.size
    end

    def authentic? uname, uid
      NineP.vputs { [ "Authenticating #{@user}", @data.inspect, @environment.find_user(@user).inspect ] }
      (@user == uname || @user == uid) && @environment.auth(@user, @data)
    end

    def dup
      self.class.new(environment, user, data)
    end
  end
end
