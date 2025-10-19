require 'sg/defer'

class NonoP::Client
  class PendingValue < SG::Defer::Value
    def initialize client
      super() do
        client.process_one until ready?
        _1
      end
    end
  end
end
