module NonoP
  class Error < RuntimeError
  end

  class NotReady < RuntimeError
  end

  class ProtocolError < Error
    attr_reader :code, :sys
    
    def initialize err, msg = nil
      @code = err
      @sys = SystemCallError.new(msg,
                                 case err
                                 when Integer then err
                                 when SystemCallError then err.errno
                                 when ErrorPayload then err.code
                                 else err
                                 end)
      super(@sys.message)
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
  class ClunkError < ProtocolError
  end
  class ReadError < ProtocolError
  end
  class WriteError < ProtocolError
  end
  class GetAttrError < ProtocolError
  end
  class MkdirError < ProtocolError
  end
  class StatError < ProtocolError
  end
end
