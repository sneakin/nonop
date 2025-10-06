require_relative '../spec-helper'

describe 'nonop ls' do
  include NonoP::SpecHelper
  
  DateRegex = /(\d+)\/(\d+)\/(\d+)/
  TimeRegex = /(\d+):(\d+):(\d+)/

  def stats_table str
    stats = [ uid.to_s, gid.to_s, DateRegex, TimeRegex ]
    str.split("\n").collect {
      _1.include?(':') ? [ _1 ] : [ *_1.split, *stats ]
    }
  end
  
  describe 'on a test server' do
    let(:rm_size) { Pathname.new(__FILE__).parent.parent.parent.join('README.md').size }
    let(:src_size) { Pathname.new(__FILE__).parent.parent.parent.size }

    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    describe 'with ctl aname' do
      def run_ls *args, &blk
        run_nonop('ls', '--host', 'localhost', '--port', NonoP::SpecHelper::PORT.to_s, '--aname', 'ctl', *args, &blk)
      end
      
      describe 'no paths' do
        it 'lists the root directory' do
          run_ls do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  README.md
  config
  info
EOT
          end
        end

        it 'sorts by size with "--sort size"' do
          run_ls('--sort', 'size') do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  info
  config
  README.md
EOT
          end
        end

        describe 'with "-l"' do
          let(:uid) { Process.uid }
          let(:gid) { Process.gid }
          
          it 'prints the stats with "-l"' do
            run_ls('-l') do |io|
              expect(strip_escapes(io.read)).
                to be_table_of(stats_table(<<-EOT))
/:
  README.md          #{rm_size}  -r--r-----
  config             3           dr-xr-x---
  info               2           dr-xr-x---
EOT
            end
          end

          it 'sorts by size with "--sort size"' do
            run_ls('-l', '--sort', 'size') do |io|
              expect(strip_escapes(io.read)).
                to be_table_of(stats_table(<<-EOT))
/:
  info               2           dr-xr-x---
  config             3           dr-xr-x---
  README.md          #{rm_size}  -r--r-----
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

    describe 'with spec aname' do
      def run_ls *args, &blk
        run_nonop('ls', '--host', 'localhost', '--port', NonoP::SpecHelper::PORT.to_s, '--aname', 'spec', *args, &blk)
      end
      
      describe 'no paths' do
        it 'lists the root directory' do
          run_ls do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  README.md
  fifo
  info
  scratch
  src
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
  welcome
  src
  README.md
EOT
          end
        end

        describe 'with "-l"' do
          let(:uid) { Process.uid }
          let(:gid) { Process.gid }
          
          it 'prints the stats with "-l"' do
            run_ls('-l') do |io|
              expect(strip_escapes(io.read)).
                to be_table_of(stats_table(<<-EOT))
/:
  README.md          #{rm_size}   -r--r-----
  fifo               0            prw-r-----
  info               2            dr-xr-x---
  scratch            0            -rw-------
  src                #{src_size}  dr-xr-x---
  tmp                0            drwxr-x---
  welcome            7            -rw-r-----
EOT
            end
          end

          it 'sorts by size with "--sort size"' do
            run_ls('-l', '--sort', 'size') do |io|
              expect(strip_escapes(io.read)).
                to be_table_of(stats_table(<<-EOT))
/:
  scratch            0            -rw-------
  fifo               0            prw-r-----
  tmp                0            drwxr-x---
  info               2            dr-xr-x---
  welcome            7            -rw-r-----
  src                #{src_size}  dr-xr-x---
  README.md          #{rm_size}   -r--r-----
EOT
            end
          end
        end
      end
      
      describe 'with paths' do
        it 'exits w/ 0 code' do
          expect { run_ls('src', 'info') }.
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
bad:
info:
  now
  stats
EOT
          end
        end
      end
    end
    
    describe 'with aname="basic"' do
      def run_ls *args, &blk
        run_nonop('ls', '--host', 'localhost', '--port', NonoP::SpecHelper::PORT.to_s, '--aname', 'basic', *args, &blk)
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
      expect { run_ls('--host', 'example.local', '--port', NonoP::SpecHelper::PORT.to_s) }.to change { @status&.exitstatus }.to(1)
    end
    xit 'a bad host exits w/ an error' do
      expect { run_ls('--host', 'example.com', '--port', NonoP::SpecHelper::PORT.to_s) }.to change { @status&.exitstatus }.to(1)
    end
    it 'a bad port exits w/ an error' do
      expect { run_ls('--host', 'localhost', '--port', '20000') }.to change { @status&.exitstatus }.to(1)
    end
  end
end
