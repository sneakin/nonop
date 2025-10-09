module NonoP::Server
  class ACL
    def self.from_script path
      Class.new(self) do
        instance_eval(File.read(path), path)
      end
    end
    
    def auth? export: nil, user: nil, remote_address: nil, **opts
      false
    end
    
    def attach? export, user: nil, remote_address: nil, **opts
      false
    end

    def attach_as? export, user: nil, as: nil, remote_address: nil, **opts
      false
    end
  end

  class YesAcl < ACL
    def auth? export: nil, user: nil, remote_address: nil, **opts
      true
    end

    def attach? export, user: nil, remote_address: nil, **opts
      true
    end

    def attach_as? export, user: nil, as: nil, remote_address: nil, **opts
      true
    end
  end

  class HashAcl < ACL
    def initialize db
      @db = db
    end

    def auth? export: nil, user: nil, remote_address: nil, **opts
      fs = @db.fetch('auth').fetch(export)
      NonoP.vputs { [ "auth? #{user}", fs.inspect ] }
      fs[user&.name]
    rescue KeyError
      false
    end

    def attach? export, user: nil, remote_address: nil, **opts
      fs = @db.fetch('attach').fetch(export)
      NonoP.vputs { [ "attach? #{user}", fs.inspect ] }
      fs[user.name]
    rescue KeyError
      false
    end

    def attach_as? export, user:, as:, remote_address: nil, **opts
      fs = @db.fetch('attach').fetch(export)
      NonoP.vputs { [ "attach as? #{user} #{as}", fs.inspect ] }
      fs[user.name] == true || (Array === fs[user.name] && (user == as || fs[user.name].include?(as.name)))
    rescue KeyError
      false
    end
  end
end
