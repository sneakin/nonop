module NineP
  class Error < RuntimeError
  end

  class NotReady < RuntimeError
  end
    
  class ProtocolError < Error
    def initialize err, msg = nil
      sys = SystemCallError.new(msg, Integer === err ? err : err.code)
      super(sys.message)
    end
  end

  class StartError < ProtocolError
  end
  class AuthError < ProtocolError
  end
  class AttachError < ProtocolError
  end
  class WalkError < ProtocolError
  end
  class OpenError < ProtocolError
  end
  class CreateError < ProtocolError
  end
  class ReadError < ProtocolError
  end
  class WriteError < ProtocolError
  end
  class GetAttrError < ProtocolError
  end
end
