describe 'ninep ls' do
  NINEP_PATH = 'bin/ninep'
  
  def run_ninep *args, &blk
    blk ||= lambda { _1.read }
    data = IO.popen([ 'bundle', 'exec', NINEP_PATH, *args], 'r', &blk)
    @status = $?
    data
  end

  def start_server *args
    pid = Process.spawn('bundle', 'exec', NINEP_PATH, 'server', '--port', '10000', '--auth-provider', 'yes', *args)
    now = Time.at(Time.now.to_i + 1).strftime("%x %X") # fixme regex match? data table?
    sleep(2) # fixme need a signal of sorts
    [ pid, now ]
  end

  def strip_escapes str
    str.gsub(/\e\[[^m]*m/, '').gsub(/\s+($|\Z)/, '') + "\n"
  end

  describe 'on a test server' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      Process.kill('TERM', @server)
      Process.wait(@server)
    end

    describe 'with ctl aname' do
      def run_ls *args, &blk
        run_ninep('ls', '--host', 'localhost', '--port', '10000', '--aname', 'ctl', *args, &blk)
      end
      
      describe 'no paths' do
        it 'lists the root directory' do
          run_ls do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  README.md
  config
  info
  scratch
  welcome
EOT
          end
        end

        it 'sorts by size with "--sort size"' do
          run_ls('--sort', 'size') do |io|
            expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  scratch
  info
  config
  welcome
  README.md
EOT
          end
        end

        describe 'with "-l"' do
          let(:uid) { Process.uid }
          let(:gid) { Process.gid }
          
          it 'prints the stats with "-l"' do
            run_ls('-l') do |io|
              expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  README.md        289 100440     #{uid}     #{gid}  #{@started_at}
  config             3  40750     #{uid}     #{gid}  #{@started_at}
  info               2  40750     #{uid}     #{gid}  #{@started_at}
  scratch            0 100640     #{uid}     #{gid}  #{@started_at}
  welcome            7 100640     #{uid}     #{gid}  #{@started_at}
EOT
            end
          end

          it 'sorts by size with "--sort size"' do
            run_ls('-l', '--sort', 'size') do |io|
              expect(strip_escapes(io.read)).to eql(<<-EOT)
/:
  scratch            0 100640     #{uid}     #{gid}  #{@started_at}
  info               2  40750     #{uid}     #{gid}  #{@started_at}
  config             3  40750     #{uid}     #{gid}  #{@started_at}
  welcome            7 100640     #{uid}     #{gid}  #{@started_at}
  README.md        289 100440     #{uid}     #{gid}  #{@started_at}
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
        
        it 'with a bad one, exits w/ 0 too' do # fixme?
          expect { run_ls('config', 'bad', 'info') }.
            to change { @status&.exitstatus }.to(0)
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
        run_ninep('ls', '--host', 'localhost', '--port', '10000', '--aname', '/', *args, &blk)
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
      run_ninep('ls', '--aname', 'ctl', *args)
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
