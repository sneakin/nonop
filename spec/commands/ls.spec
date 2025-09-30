require_relative '../spec-helper'

describe 'nonop ls' do
  include NonoP::SpecHelper
  
  describe 'on a test server' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    describe 'with ctl aname' do
      def run_ls *args, &blk
        run_nonop('ls', '--host', 'localhost', '--port', '10000', '--aname', 'ctl', *args, &blk)
      end
      
      describe 'no paths' do
        it 'lists the root directory' do
          run_ls do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  README.md
  config
  fifo
  info
  scratch
  tmp
  welcome
EOT
          end
        end

        it 'sorts by size with "--sort size"' do
          run_ls('--sort', 'size') do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  scratch
  fifo
  tmp
  info
  config
  welcome
  README.md
EOT
          end
        end

        DateRegex = /(\d+)\/(\d+)\/(\d+)/
        TimeRegex = /(\d+):(\d+):(\d+)/

        def stats_table str
          stats = [ uid.to_s, gid.to_s, DateRegex, TimeRegex ]
          str.split("\n").collect {
            _1.include?(':') ? [ _1 ] : [ *_1.split, *stats ]
          }
        end
        
        describe 'with "-l"' do
          let(:uid) { Process.uid }
          let(:gid) { Process.gid }
          
          it 'prints the stats with "-l"' do
            run_ls('-l') do |io|
              expect(strip_escapes(io.read)).
                to be_table_of(stats_table(<<-EOT))
/:
  README.md        289  100440
  config             3   40550
  fifo               0 1000640
  info               2   40550
  scratch            0  100640
  tmp                0   40750
  welcome            7  100640
gEOT
            end
          end

          it 'sorts by size with "--sort size"' do
            run_ls('-l', '--sort', 'size') do |io|
              expect(strip_escapes(io.read)).
                to be_table_of(stats_table(<<-EOT))
/:
  scratch            0  100640
  fifo               0 1000640
  tmp                0   40750
  info               2   40550
  config             3   40550
  welcome            7  100640
  README.md        289  100440
EOT
            end
          end
        end
      end
      
      describe 'with paths' do
        it 'exits w/ 0 code' do
          expect { run_ls('config', 'info') }.
            to change { @status&.exitstatus }.to(0)
        end
        
        it 'with a bad one, exits w/ 1' do
          expect { run_ls('config', 'bad', 'info') }.
            to change { @status&.exitstatus }.to(1)
        end
        
        it 'lists the directories' do
          run_ls('config', 'bad', 'info') do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
config:
  README
  done
  verbose
bad:
info:
  now
  stats
EOT
          end
        end
      end
    end
    
    describe 'with aname="/"' do
      def run_ls *args, &blk
        run_nonop('ls', '--host', 'localhost', '--port', '10000', '--aname', '/', *args, &blk)
      end
      
      describe 'no paths' do
        it 'lists the root directory' do
          run_ls do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  abcd
  utf8.txt
EOT
          end
        end
      end
    end
  end
  
  describe 'nonexisting server' do
    def run_ls *args
      run_nonop('ls', '--aname', 'ctl', *args)
    end

    it 'a bad host exits w/ an error' do
      expect { run_ls('--host', 'example.local', '--port', '10000') }.to change { @status&.exitstatus }.to(1)
    end
    xit 'a bad host exits w/ an error' do
      expect { run_ls('--host', 'example.com', '--port', '10000') }.to change { @status&.exitstatus }.to(1)
    end
    it 'a bad port exits w/ an error' do
      expect { run_ls('--host', 'localhost', '--port', '20000') }.to change { @status&.exitstatus }.to(1)
    end
  end
end
