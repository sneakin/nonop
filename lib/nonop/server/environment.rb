require 'sg/ext'
using SG::Ext

module NonoP::Server
  class Environment
    attr_reader :reactor
    attr_reader :authsrv, :auth_qid, :acl
    attr_reader :exports, :connections

    def initialize reactor:, authsrv: nil, acl: nil, needs_auth: true
      @reactor = reactor
      @authsrv = authsrv
      @acl = acl || YesAcl.new
      @exports = {}
      @auth_qid = NonoP::Qid.new(type: NonoP::Qid::Types[:AUTH], version: 0, path: '')
      @started_at = Time.now
      @connections = {}
      @needs_auth = needs_auth
    end

    def needs_auth?; @needs_auth; end

    def export name, fs
      @exports[name] = fs
      self
    end

    def get_export name
      @exports.fetch(name)
    end

    delegate :authenticate, :find_user, :has_user?, to: :authsrv

    def track_connection conn
      @connections[conn] = conn
      self
    end

    def untrack_connection conn
      @connections.delete(conn)
      self
    end

    def stats
      { exports: exports.keys,
        connections: connections.size,
        users: authsrv.user_count,
        now: Time.now,
        uptime: Time.now - @started_at,
        started_at: @started_at
      }
    end

    def done! &cc
      @connections.values.each(&:close)
      cc.call
    end
  end
end
