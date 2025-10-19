require 'sg/ext'
using SG::Ext

require 'sg/promise'
require_relative 'pending-value'

class NonoP::Client
  class Promise < SG::Promise
    def initialize client, fn = nil, &blk
      super(fn, value: PendingValue.new(client), &blk)
    end

    delegate :ready?, to: :value

    def called?; @called; end
  
    def call(...)
      return value.wait if @called
      @called = true
      super
    end
    
    def wait
      call
      value.wait
    end
    
    def new_sibling &blk
      Promise.new(@client, &blk)
    end
  end
end
