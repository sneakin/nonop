require 'nonop/client'
require 'sg/defer'
require 'sg/attr_struct'
require 'sg/hash_struct'

module ClientHelper
  class State
    include SG::AttrStruct
    include SG::HashStruct
    attributes :username, :uid, :creds, :afid, :aname
  end

  def self.default_state
    ClientHelper::State.new(username: ENV.fetch('USER'),
                            uid: Process.uid,
                            creds: 'YES',
                            afid: 123,
                            aname: 'spec')
  end    
  
  def self.included base
    base.let(:sock) { TCPSocket.new('localhost', NonoP::SpecHelper::PORT) }
    base.let(:client) { NonoP::Client.new(io: sock) }

    base.after do
      client.close
    end
  end
end
