require 'sg/ext'
using SG::Ext

module NonoP
  module Async
    # Iterates through an Enumerable collecting state using callbacks
    # to allow interuptions.
    #
    # @param data_maker [Enumerable] Generates data to reduce
    # @param state [Array<Object>] Your state variables
    # @param final_cc [Proc] Internal variable for the final actions.
    # @return [Array<Object>, StandardError] Your state
    # @raise StandardError
    # @yield [data, *state, cc] Process your data and update state by calling ~cc~.
    # @yieldparam data [Object]
    # @yieldparam state [Array<Object>]
    # @yieldparam cc [Proc] Call this with a Boolean or Error and your state to advance to the next step.
    def self.reduce data_maker, *state, final_cc: nil, &blk
      data_maker = data_maker.each if data_maker && !(Enumerator === data_maker)
      head = data_maker.next
      raise StopIteration if StopIteration == head
      blk.call(head, *state) do |done, *state, &cc|
        case done
        when StandardError then cc ? cc.call(done, *state) : raise(done)
        when false then reduce(data_maker, *state, final_cc: cc, &blk)
        else cc ? cc.call(done, *state) : state
        end
      end
    rescue StopIteration
      final_cc ? final_cc.call(true, *state) : state
    end
  end
end
