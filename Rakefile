$ROOT = Pathname.new(__FILE__).parent
$NAME = 'NonoP'
$VERSION = '0.1.0'
$SOURCE_FILES = []
$EXTRA_FILES = [ 'doc/protocol.md',
                 'doc/reports.md',
                 'examples/**/*.{rb,nonofs}',
                 'spec/spec-fs.nonofs',
                 'scripts/protocol-scanner']
require 'sg/rake/tasks'

namespace :spec do
  desc 'Run the RSpec test suit'
  RSpec::Core::RakeTask.new(:requests) do |t|
    ENV['DRIVER'] = 'requests'
    rspec_opts = %w{
      -f json -o doc/spec-requests.json
      -f progress
      --failure-exit-code 0
    }
    t.rspec_opts = Shellwords.join(rspec_opts)
    t.pattern = 'spec/integration/**/*.spec'
  end
end

task :doc => [ 'doc/reports.md' ]

file 'doc/spec-requests.json' => 'spec:requests'

file 'doc/reports.md' => [ 'doc/spec.json', 'doc/spec-requests.json' ] do |t|
  require 'async'
  require 'erb'
  Async do
    specs = Async { IO.popen("sg-rspec-report --style org < doc/spec.json", &:read) }
    proto_client = Async { IO.popen("sg-rspec-report -f scripts/spec-proto-op-status.rb --style org < doc/spec.json", &:read) }
    proto_reqs = Async { IO.popen("sg-rspec-report -f scripts/spec-proto-op-status.rb --style org < doc/spec-requests.json", &:read) }
    File.open(t.name, 'w') do |f|
      f.write(ERB.new(File.read('doc/reports.md.erb'), trim_mode: '-').
              result_with_hash(specs: specs.wait,
                               proto_client: proto_client.wait,
                               proto_reqs: proto_reqs.wait))
    end
  end
end

desc 'Generate the protocol message structures.'
task 'generate' => [ 'lib/nonop/protocol/messages.rb' ]

directory 'lib/nonop/protocol'
file 'lib/nonop/protocol/messages.rb' =>
  [ 'doc/protocol.md',
    'scripts/protocol-scanner',
    'lib/nonop/protocol' ] do |t|
  sh("scripts/protocol-scanner doc/protocol.md > #{t.name}")
end
