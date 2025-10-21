require 'sg/defer'

class NonoP::Client
  class PendingValue < SG::Defer::Value
    def initialize client
      super() do
        client.process_one until ready?
        @value
      rescue
        NonoP.vputs { "PV saw #{$!}" }
        $!
      end
    end
  end
end
