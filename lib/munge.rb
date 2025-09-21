module Munge
  def self.encode uid: nil, gid: nil, ttl: nil, &blk
    cmd = ['/usr/bin/munge']
    cmd += [ '-U', uid ] if uid
    cmd += [ '-G', gid ] if gid
    cmd += [ '-t', ttl ] if ttl
    cred = nil
    IO.popen(cmd.collect(&:to_s), 'w+') do |io|
      blk&.call(io)
      io.close_write
      cred = io.read
      io.close
    end
    cred
  end
end
