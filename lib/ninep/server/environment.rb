require 'sg/ext'
using SG::Ext

module NineP::Server
  class Environment
    attr_reader :authsrv, :auth_qid
    attr_reader :exports, :connections

    def initialize authsrv: nil
      @authsrv = authsrv
      @exports = {}
      @auth_qid = NineP::Qid.new(type: NineP::Qid::Types[:AUTH], version: 0, path: '')
      @started_at = Time.now
      @connections = {}
    end

    def export name, fs
      @exports[name] = fs
      self
    end

    def get_export name
      @exports.fetch(name)
    end

    delegate :auth, :find_user, :has_user?, to: :authsrv

    def track_connection conn
      @connections[conn] = conn
      self
    end

    def untrack_connection conn
      @connections.delete(conn)
      self
    end

    def stats
      { exports: exports.size,
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
