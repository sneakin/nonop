require 'sg/ext'
using SG::Ext

require 'ninep'

module NineP
  module Server
    autoload :FileSystem, 'ninep/server/file-system'
    autoload :HashFileSystem, 'ninep/server/hash-file-system'
    autoload :AuthService, 'ninep/server/auth'
    autoload :AuthHash, 'ninep/server/auth'
    autoload :YesAuth, 'ninep/server/auth'
    autoload :MungeAuth, 'ninep/server/auth'
    autoload :Stream, 'ninep/server/stream'
    autoload :ErrantStream, 'ninep/server/streams/errant-stream'
    autoload :AuthStream, 'ninep/server/streams/auth-stream'
    autoload :AttachStream, 'ninep/server/streams/attach-stream'
    autoload :FileStream, 'ninep/server/streams/file-stream'
    autoload :Environment, 'ninep/server/environment'
    autoload :Connection, 'ninep/server/connection'
  end
end
