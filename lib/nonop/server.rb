require 'sg/ext'
using SG::Ext

require 'nonop'

module NonoP
  module Server
    autoload :FileSystem, 'nonop/server/file-system'
    autoload :HashFileSystem, 'nonop/server/hash-file-system'
    autoload :AuthService, 'nonop/server/auth'
    autoload :AuthHash, 'nonop/server/auth'
    autoload :YesAuth, 'nonop/server/auth'
    autoload :MungeAuth, 'nonop/server/auth'
    autoload :ACL, 'nonop/server/acl'
    autoload :YesAcl, 'nonop/server/acl'
    autoload :HashAcl, 'nonop/server/acl'
    autoload :Stream, 'nonop/server/stream'
    autoload :ErrantStream, 'nonop/server/streams/errant-stream'
    autoload :AuthStream, 'nonop/server/streams/auth-stream'
    autoload :AttachStream, 'nonop/server/streams/attach-stream'
    autoload :FileStream, 'nonop/server/streams/file-stream'
    autoload :Environment, 'nonop/server/environment'
    autoload :Connection, 'nonop/server/connection'
  end
end
