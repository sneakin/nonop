require 'nonop/bit-field'

module NonoP
  PermBits = {
    DIR:    040000,
    CHAR:   020000,
    BLOCK:  010000,
    FILE:   0100000,
    FIFO:   0010000,
    LINK:   0120000,
    SOCK:   0140000,

    SUID:   04000,
    SGID:   02000,
    STICKY: 01000,
    W:      0222,
    R:      0444,
    X:      0111,
  }
  PermMode = NonoP::BitField.
    new(PermBits, {
          FTYPE:  0170000,
          PERMS:  0007777,
          FLAG:   07000,
          OTHER:  00007,
          GROUP:  00070,
          USER:   00700,
          RWX:    PermBits[:R] | PermBits[:W] | PermBits[:X],
          RX:     PermBits[:R] | PermBits[:X],
          RW:     PermBits[:R] | PermBits[:W],
        })

  def self.perm_mode_string mode
    [ mode & :DIR ? 'd' : (mode & :FIFO ? 'p' : '-'),
      [ :USER, :GROUP, :OTHER ].collect { |mask|
        bits = mode.mask(mask)
        { R: 'r', W: 'w', X: 'x' }.collect { |bit, str|
          bits & bit ? str : '-'
        }
      }
    ].flatten.join
  end
end
