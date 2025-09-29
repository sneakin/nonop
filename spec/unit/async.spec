require 'sg/ext'
using SG::Ext

require 'nonop/async'

describe NonoP::Async do
  let(:test_data) { [ 1, 2, 3, 4 ] }

  describe '.reduce' do
    it 'loops through data provided by a proc' do
      r = NonoP::Async.reduce(test_data, []) do |el, acc, &cc|
        cc.call(el == 3, acc + [ el * el ])
      end
      expect(r).to eql([[1,4,9]])
    end

    it 'does not loop when the continuation is not called' do
      r = NonoP::Async.reduce(test_data, []) do |el, acc, &cc|
        [ acc + [ el * el ] ]
      end
      expect(r).to eql([[1]])
    end

    it 'calls the continuation block once at the end' do
      en = test_data.each
      fin_calls = 0
      r = NonoP::Async.reduce(test_data, []) do |el, acc, &cc|
        cc.call(el == 3, acc + [ el * el ]) do |facc|
          expect(facc).to eql([1,4,9])
          fin_calls += 1
          :done
        end
      end
      expect(r).to eql(:done)
      expect(fin_calls).to eql(1)
    end

    it 'is interruptible' do
      en = test_data.each
      delayed_fn = nil
      final_acc = nil
      r = NonoP::Async.reduce(test_data, []) do |el, acc, &cc|
        if el == 1
          delayed_fn = lambda do
            cc.call(el == 3, acc + [ el * el ]) do |acc|
              puts :madeit
              final_acc = acc
              expect(acc).to eql([1,4,9])
              break :here
            end
          end
          break :b
        else
          puts :cont
          cc.call(false, acc + [ el * el ])
        end
        "post-#{el}"
      end
      expect(final_acc).to eql(nil)
      expect(r).to be(:b)
      expect(delayed_fn).to be_kind_of(Proc)
      r = delayed_fn.call
      expect(r).to eql(:here)
      expect(final_acc).to eql([1,4,9])
    end
  end
end

