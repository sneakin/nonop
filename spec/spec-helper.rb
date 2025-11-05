require 'sg/ext'
using SG::Ext

require 'nonop/util'

$verbose = ENV['VERBOSE'].to_bool

module NonoP::SpecHelper
  NONOP_PATH = 'bin/nonop'
  PORT = 10000 + (Process.pid % 1024)
  
  def run_nonop *args, mode: nil, &blk
    blk ||= /^w/ === mode ? lambda { |_| true } : lambda { _1.read }
    data = IO.popen([ 'bundle', 'exec', NONOP_PATH, *args],
                    mode || 'r',
                    &blk)
    @status = $?
    data
  end

  def start_server *args
    unless args.find(&/-e|--export/)
      args += [ '--export', 'spec:spec/spec-fs.nonofs',
                '--export', 'basic:examples/basic-fs.rb' ]
    end
    pid = Process.spawn('bundle', 'exec', NONOP_PATH, 'server',
                        '--port', PORT.to_s,
                        '--auth-provider', 'yes',
                        '--acl', 'spec/spec-acl.rb',
                        *args)
    now = Time.at(Time.now.to_i + 1).strftime("%x %X")
    sleep(2) # fixme need a ready signal of sorts
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

RSpec::Matchers.define :be_table_of do |data|
  match do |actual|
    @failures = []
    @actual = case actual
              when String then actual.split("\n").collect(&:split)
              else actual
              end
    @actual.zip(data).all? do |output, expecting|
      output.zip(expecting).all? do |o, e|
        case e
        when Class, Regexp then e === o
        else o == e
        end
      end.tap { @failures << [ output, expecting ] unless _1 }
    end
  end

  failure_message do |actual|
    @failures.collect { "   %s\n!= %s" % [ _1.inspect, _2.inspect ] }.join("\n")
  end
end
