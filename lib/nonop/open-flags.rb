require_relative 'bit-field'

module NonoP
  OpenFlags = BitField.
    new({ RDONLY:        00000000,
          WRONLY:        00000001,
          RDWR:          00000002,
          NOACCESS:      00000003,
          CREATE:        00000100,
          EXCL:          00000200,
          NOCTTY:        00000400,
          TRUNC:         00001000,
          APPEND:        00002000,
          NONBLOCK:      00004000,
          DSYNC:         00010000,
          FASYNC:        00020000,
          DIRECT:        00040000,
          LARGEFILE:     00100000,
          DIRECTORY:     00200000,
          NOFOLLOW:      00400000,
          NOATIME:       01000000,
          CLOEXEC:       02000000,
          SYNC:          04000000
        }, {
          MODE: 0xF,
          OPTS: 0xFFFFFFF0,
        }, 'OpenFlags')
end  
