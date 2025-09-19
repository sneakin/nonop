require 'sg/ext'
using SG::Ext

module NineP
  module Async
    def self.reduce data_maker, *state, final_cc: nil, &blk
      data_maker = data_maker.each if data_maker && !(Enumerator === data_maker)
      head = data_maker.next
      raise StopIteration if StopIteration == head
      blk.call(head, *state) do |done, *state, &cc|
        case done
        when StandardError then cc ? cc.call(done) : done
        when false then reduce(data_maker, *state, final_cc: cc, &blk)
        else cc ? cc.call(*state) : state
        end
      end
    rescue StopIteration
      if final_cc
        final_cc.call(*state)
      else
        return state
      end
    end
  end
end
