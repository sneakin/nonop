module NonoP::Server
  class ACL
    def auth? export: nil, user: nil, uid: nil, remote_addr: nil, **opts
      false
    end
    
    def attach? export, user: nil, uid: nil, remote_addr: nil, **opts
      false
    end
  end

  class YesAcl < ACL
    def auth? export: nil, user: nil, uid: nil, remote_addr: nil, **opts
      true
    end

    def attach? export, user: nil, uid: nil, remote_addr: nil, **opts
      true
    end
  end

  class HashAcl < ACL
    def initialize db
      @db = db
    end

    def auth? export: nil, user: nil, uid: nil, remote_addr: nil, **opts
      fs = @db.fetch('auth').fetch(export)
      fs[user] || fs[uid]
    rescue KeyError
      false
    end

    def attach? export, user: nil, uid: nil, remote_addr: nil, **opts
      fs = @db.fetch('attach').fetch(export)
      fs[user] || fs[uid]
    rescue KeyError
      false
    end
  end
end
