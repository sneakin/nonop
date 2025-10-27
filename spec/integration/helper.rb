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
    base.extend(ClassMethods)
    base.let(:sock) { TCPSocket.new('localhost', NonoP::SpecHelper::PORT) }
    base.let(:client) { NonoP::Client.new(io: sock) }

    base.after do
      client.close
    end
  end

  module ClassMethods
    def path_hash path_body
      Hash[[ :at, :contents ].zip(path_body)]
    end
  end

  def read_back(path, amount)
    # todo File.open like block w/ close
    # r = nil
    attachment.open(path) do |rio|
      rio.read(amount).tap { rio.close.wait }
    end.wait
  end
  
end
