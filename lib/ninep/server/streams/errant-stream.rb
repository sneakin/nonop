require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NineP::Server
  class ErrantStream < Stream
    include Singleton
  end
end
