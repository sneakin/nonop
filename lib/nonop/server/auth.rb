require 'sg/ext'
using SG::Ext

module NonoP::Server
  class AuthService
    def authenticate remote_addr: nil, user: nil, uid: nil, credentials: nil
      false
    end
    def find_user user
      nil
    end
    def has_user? user
      false
    end
    def user_count
      0
    end
  end

  class AuthHash < AuthService
    def initialize db
      @db = db
    end
    def authenticate remote_addr: nil, user: nil, uid: nil, credentials: nil
      u = find_user(uid) || find_user(user)
      u && u[1] == credentials.strip
    end
    def find_user user
      case user
      when String then @db[user]
      when Integer then @db.find { _2[0] == user }&.then { _2 }
      when nil then false
      else raise TypeError.new("User not a string or ID but a #{user.inspect}")
      end
    end
    def has_user? user
      find_user(user) != nil
    end
    def user_count
      @db.size
    end
  end

  class YesAuth < AuthHash
    def authenticate remote_addr: nil, user: nil, uid: nil, credentials: nil
      has_user?(user) || has_user?(uid)
    end
  end

  class MungeAuth < AuthHash
    def authenticate remote_addr: nil, user: nil, uid: nil, credentials: nil
      return false unless has_user?(uid)
      status, meta, payload = Munge.verify do |io|
        io.puts(credentials)
      end
      status == 0 && meta.fetch('STATUS', '') =~ /^Success/ &&
        (uid && meta.fetch('UID', '') =~ /\(#{uid}\)/ ||
         user && meta.fetch('UID', '') =~ /#{user}/)
    end
  end
end
