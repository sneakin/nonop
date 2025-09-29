require_relative '../spec-helper'

describe 'ninep put' do
  include NineP::SpecHelper
  
  describe 'on a test server' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    describe 'with ctl aname' do
      def run_cat *args, &blk
        run_ninep('cat', '--host', 'localhost', '--port', '10000', '--aname', 'ctl', *args, &blk)
      end
      def run_put *args, &blk
        run_ninep('put', '--host', 'localhost', '--port', '10000', '--aname', 'ctl', *args, mode: 'w', &blk)
      end
      
      describe 'with paths' do
        describe 'good path' do
          it 'prints the contents' do
            run_put('scratch') do |io|
              io.puts("Hello hello")
            end
            
            run_cat('scratch') do |io|
              expect(io.read).to eql("Hello hello\n")
            end
          end
          it 'exits w/ no error' do
            expect { run_put('scratch') { _1.close } }.
              to change { @status&.exitstatus }.to(0)
          end
        end
        
        describe 'bad path' do
          it 'fails to create'
          it 'exits w/ an error' do
            expect { run_put('notfound') }.
              to change { @status&.exitstatus }.to(1)
          end
        end

        describe 'good and bad path' do
          it 'updates just the first path' do
            run_put('scratch', 'bad', 'huh') do |io|
              io.puts("Hey")
            end
            
            run_cat('scratch') do |io|
              expect(io.read).to eql("Hey\n")
            end
          end
          it 'exits w/ no error' do
            expect { run_put('scratch', 'bad', 'scratch') { _1.puts("Hey") } }.
              to change { @status&.exitstatus }.to(0)
          end
        end

      end
    end
  end

  describe 'nonexisting server' do
    def run_put *args
      run_ninep('put', '--aname', 'ctl', *args)
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
