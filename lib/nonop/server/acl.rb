module NonoP::Server
  class ACL
    def attach? export, user: nil, uid: nil, remote_addr: nil, **opts
      false
    end
  end

  class YesAcl < ACL
    def attach? export, user: nil, uid: nil, remote_addr: nil, **opts
      true
    end
  end

  class HashAcl < ACL
    def initialize db
      @db = db
    end

    def attach? export, user: nil, uid: nil, remote_addr: nil, **opts
      fs = @db.fetch(export)
      fs[user] || fs[uid]
    rescue KeyError
      false
    end
  end
end
