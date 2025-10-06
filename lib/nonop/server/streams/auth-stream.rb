require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NonoP::Server
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
      NonoP.vputs { [ "Authenticating #{@user} #{uname} #{uid}", @data.inspect, @environment.find_user(@user).inspect ] }
      (@user == uname || @user == uid) &&
        @environment.authenticate(@user, @data)
    end

    def dup
      self.class.new(environment, user, data)
    end
  end
end
