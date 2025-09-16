module NineP
  class Error < RuntimeError
  end

  class NotReady < RuntimeError
  end
    
  class ProtocolError < Error
    def initialize err, msg = nil
      sys = SystemCallError.new(msg, err.code)
      super(sys.message)
    end
  end

  class StartError < ProtocolError
  end
  class AuthError < ProtocolError
  end
  class AttachError < ProtocolError
  end
  class ReadError < ProtocolError
  end
  class WalkError < ProtocolError
  end
  class GetAttrError < ProtocolError
  end
end
