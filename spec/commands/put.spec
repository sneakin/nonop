require_relative '../spec-helper'

describe 'nonop put' do
  include NonoP::SpecHelper
  
  describe 'on a test server' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    describe 'with spec aname' do
      def run_cat *args, &blk
        run_nonop('cat', '--host', 'localhost', '--port', '10000', '--aname', 'spec', *args, &blk)
      end
      def run_put *args, &blk
        run_nonop('put', '--host', 'localhost', '--port', '10000', '--aname', 'spec', *args, mode: 'w', &blk)
      end

      shared_examples_for 'happy put' do |target:, content: 'Foo bar'|
        target = [ target ] unless Enumerable === target
        
        it 'writes the contents' do
          run_put(*target) { |io| io.puts(content) }
          run_cat(target.first) { |io|
            expect(io.read).to eql(content + "\n")
          }
        end

        if target.size > 1
          it 'writes only the first path' do
            run_put(*target) { |io| io.puts(content) }
            target[1...-1].each { |tgt|
              run_cat(tgt) { |io|
                expect(io.read).to_not eql(content + "\n")
              }
            }
          end
        end

        it 'exits w/ no error' do
          expect { run_put(*target) { _1.puts(content) } }.
            to change { @status&.exitstatus }.to(0)
        end
      end
      
      describe 'with paths' do
        describe 'good path' do
          it_should_behave_like 'happy put', target: 'scratch', content: 'Hello hello'
        end
        
        describe 'bad path' do
          describe 'fails to create' do
            it 'does not change the contents' do
              content = 'Not this time.'
              run_put('notfound') { |io| io.puts(content) }
              run_cat('notfound') { |io|
                expect(io.read).to eql("")
              }
            end
            it 'exits w/ an error' do
              expect { run_put('notfound') }.
                to change { @status&.exitstatus }.to(1)
            end
          end

          describe 'can create' do
            it_should_behave_like 'happy put', target: ['tmp/hello'], content: 'Hello hello'
            it_should_behave_like 'happy put', target: ['tmp/again'], content: 'Hello'
            it_should_behave_like 'happy put', target: ['tmp/again'], content: 'Hello again'
          end
        end

        describe 'good and bad path' do
          it_should_behave_like 'happy put', target: ['scratch', 'bad', 'scratch'], content: 'Hello hello'
        end
      end
    end
  end

  describe 'nonexisting server' do
    def run_put *args
      run_nonop('put', '--aname', 'spec', *args)
    end

    it 'a bad host exits w/ an error' do
      expect { run_put('scratch', '--host', 'example.local', '--port', '10000') }.to change { @status&.exitstatus }.to(1)
    end
    xit 'a bad host exits w/ an error' do
      expect { run_put('scratch', '--host', 'example.com', '--port', '10000') }.to change { @status&.exitstatus }.to(1)
    end
    it 'a bad port exits w/ an error' do
      expect { run_put('scratch', '--host', 'localhost', '--port', '20000') }.to change { @status&.exitstatus }.to(1)
    end
  end
end
