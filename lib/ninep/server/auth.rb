require 'sg/ext'
using SG::Ext

module NineP::Server
  class AuthService
    def auth user, creds
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
    def auth user, creds
      u = find_user(user)
      u && u[1] == creds.strip
    end
    def find_user user
      case user
      when String then @db[user]
      when Integer then @db.find { _2[0] == user }&.then { _2 }
      else raise TypeError.new('User not a string or ID.')
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
    def auth user, creds
      return false unless has_user?(user)
      true
    end
  end

  class MungeAuth < AuthHash
    def auth user, creds
      return false unless has_user?(user)
      status, meta, payload = Munge.verify do |io|
        io.puts(creds)
      end
      status == 0 && meta.fetch('STATUS', '') =~ /^Success/ &&
        (Integer === user && meta.fetch('UID', '') =~ /\(#{user}\)/ ||
         String === user && meta.fetch('UID', '') =~ /#{user}/)
    end
  end
end
