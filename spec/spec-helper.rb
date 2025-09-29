module NineP
end

module NineP::SpecHelper
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

  def stop_server pid = @server
    Process.kill('TERM', pid)
    Process.wait(pid)
  end
  
  def strip_escapes str
    str.gsub(/\e\[[^m]*m/, '').gsub(/\s+($|\Z)/, '') + "\n"
  end
end
