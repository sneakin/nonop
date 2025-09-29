require_relative '../spec-helper'

describe 'nonop cat' do
  include NonoP::SpecHelper
  
  describe 'on a test server' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    describe 'with ctl aname' do
      def run_cat *args, &blk
        run_nonop('cat', '--host', 'localhost', '--port', '10000', '--aname', 'ctl', *args, &blk)
      end
      
      describe 'with paths' do
        describe 'good path' do
          it 'prints the contents' do
            run_cat('welcome') do |io|
              expect(io.read).to eql(<<-EOT)
Hello!
EOT
            end
          end
          it 'exits w/ no error' do
            expect { run_cat('welcome') }.
              to change { @status&.exitstatus }.to(0)
          end
        end
        
        describe 'bad path' do
          it 'prints nothing' do
            run_cat('notfound') do |io|
              expect(io.read).to eql('')
            end
          end
          it 'exits w/ an error' do
            expect { run_cat('notfound') }.
              to change { @status&.exitstatus }.to(1)
          end
        end

        describe 'good and bad path' do
          it 'prints the contents' do
            run_cat('welcome', 'bad', 'welcome') do |io|
              expect(io.read).to eql(<<-EOT)
Hello!
Hello!
EOT
            end
          end
          it 'exits w/ an error' do
            expect { run_cat('welcome', 'bad', 'welcome') }.
              to change { @status&.exitstatus }.to(1)
          end
        end

      end
    end
  end

  describe 'nonexisting server' do
    def run_cat *args
      run_nonop('cat', '--aname', 'ctl', *args)
    end

    it 'a bad host exits w/ an error' do
      expect { run_cat('welcome', '--host', 'example.local', '--port', '10000') }.to change { @status&.exitstatus }.to(1)
    end
    xit 'a bad host exits w/ an error' do
      expect { run_cat('welcome', '--host', 'example.com', '--port', '10000') }.to change { @status&.exitstatus }.to(1)
    end
    it 'a bad port exits w/ an error' do
      expect { run_cat('welcome', '--host', 'localhost', '--port', '20000') }.to change { @status&.exitstatus }.to(1)
    end
  end
end
