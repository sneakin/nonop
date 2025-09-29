require 'sg/ext'
using SG::Ext

require_relative '../stream'

module NonoP::Server
  class ErrantStream < Stream
    include Singleton
  end
end
