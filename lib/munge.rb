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

  def self.verify cred = nil, &blk
    cmd = ['/usr/bin/unmunge']
    meta, payload = IO.popen(cmd.collect(&:to_s), 'w+') do |io|
      io.write(cred) if cred
      blk&.call(io)
      io.close_write
      meta = io.each_line.reduce({}) do |meta, line|
        case line
        when /^(.*):\s+(.*)$/ then meta[$1] = $2
        else break meta
        end
        meta
      end
      payload = io.read
      [ meta, payload ]
    end
    NonoP.vputs { [ $?.exitstatus, meta, payload ].inspect }
# STATUS:          Success (0)
# ENCODE_HOST:     semanticgap.com (127.0.0.1)
# ENCODE_TIME:     2025-09-22 19:36:28 -0400 (1758584188)
# DECODE_TIME:     2025-09-22 19:36:28 -0400 (1758584188)
# TTL:             300
# CIPHER:          aes128 (4)
# MAC:             sha256 (5)
# ZIP:             none (0)
# UID:             mobile (1000)
# GID:             mobile (1000)
# LENGTH:          6

# hello

    [ $?.exitstatus, meta, payload ]
  end
end
