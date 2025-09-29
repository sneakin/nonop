module NineP
end

module NineP::SpecHelper
  NINEP_PATH = 'bin/ninep'
  
  def run_ninep *args, mode: nil, &blk
    blk ||= /^w/ === mode ? lambda { |_| true } : lambda { _1.read }
    data = IO.popen([ 'bundle', 'exec', NINEP_PATH, *args],
                    mode || 'r',
                    &blk)
    @status = $?
    data
  end

  def start_server *args
    pid = Process.spawn('bundle', 'exec', NINEP_PATH, 'server', '--port', '10000', '--auth-provider', 'yes', *args)
    now = Time.at(Time.now.to_i + 1).strftime("%x %X") # fixme regex match? data table?
    sleep(2) # fixme need a signal of sorts
    [ pid, now ]
  end

  def stop_server pid = @server
    Process.kill('TERM', pid)
    Process.wait(pid)
  end
  
  def strip_escapes str
    str.gsub(/\e\[[^m]*m/, '').gsub(/\s+($|\Z)/, '') + "\n"
  end
end

class String
  def table_of? data
    split("\n").collect(&:split).zip(data).all? do |output, expecting|
      output.zip(expecting).all? do |o, e|
        case e
        when Class, Regexp then e === o
        else o == e
        end
      end
    end
  end
end
