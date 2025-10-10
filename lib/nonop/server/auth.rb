require 'sg/ext'
using SG::Ext

require 'nonop/unix'

module NonoP::Server
  class AuthService
    class User
      attr_reader :name, :uid

      def eql? other
        self.class === other &&
          name.eql?(other.name) &&
          uid.eql?(other.uid)
      end

      alias == eql?

      def to_s
        "<%s name=%s uid=%s>" % [ self.class.name, name.inspect, uid.inspect ]
      end
    end

    # @return [User, FalseClass]
    def authenticate remote_address: nil, uname: nil, uid: nil, credentials: nil
      false
    end

    # @return [User]
    # @raise KeyError
    def find_user user
      nil
    end

    # @return [Boolean]
    def has_user? user
      !!find_user(user)
    end
    
    # @return [Integer]
    def user_count
      0
    end
  end

  class AuthHash < AuthService
    class User < AuthService::User
      include SG::AttrStruct
      include SG::HashStruct
      attributes :name, :uid, :secret
    end

    def initialize db
      @db = db.reduce({}) do |acc, values|
        name, uid, secret = values.flatten(1)
        acc[name] = User.new(name:, uid:, secret:)
        acc
      end
    end
    
    def authenticate remote_address: nil, uname: nil, uid: nil, credentials: nil
      u = find_user(uid) || find_user(uname)
      return u if u && u.secret == credentials.strip
    end
    
    def find_user user
      case user
      when AuthService::User then @db[user.name]
      when String then @db[user]
      when Integer then @db.find { _2.uid == user }&.then { _2 }
      when nil then false
      else raise TypeError.new("User not a string or ID but a #{user.inspect}")
      end
    end
    
    def user_count
      @db.size
    end
  end

  class YesAuth < AuthHash
    def authenticate remote_address: nil, uname: nil, uid: nil, credentials: nil
      find_user(uid) || find_user(uname)
    end
  end

  # todo get users from system
  class MungeAuth < AuthService
    class User < AuthService::User
      include SG::AttrStruct
      include SG::HashStruct
      attributes :name, :uid
    end

    attr_reader :passwd
    
    def initialize passwd: nil
      @passwd = passwd || NonoP::Unix::Passwd.new
    end
    
    def find_user user
      case user
      when AuthService::User then user
      when String then User.new(*passwd.find_by(:name, user)&.pick(:name, :uid))
      when Integer then n = user.to_i; User.new(*passwd.find_by(:uid, n)&.pick(:name, :uid))
      when nil then false
      else raise TypeError.new("User not a string or ID but a #{user.inspect}")
      end
    end
    
    def authenticate remote_address: nil, uname: nil, uid: nil, credentials: nil
      rec = find_user(uid) || find_user(uname)
      return false unless rec
      status, meta, payload = Munge.verify do |io|
        io.puts(credentials)
      end
      passed = status == 0 && meta.fetch('STATUS', '') =~ /^Success/ &&
        (uid && meta.fetch('UID', '') =~ /\(#{uid}\)/ ||
         uname && meta.fetch('UID', '') =~ /#{uname}/)
      NonoP.vputs { "#{self.class}: #{rec} #{passed}" }
      return rec if passed
    end
  end
end
