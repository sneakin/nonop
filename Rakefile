require 'bundler/setup'

$ROOT = Pathname.new(__FILE__).parent
$NAME = 'NonoP'
$VERSION = '0.1.0'
$SOURCE_FILES = []
$EXTRA_FILES = [ 'doc/protocol.md',
                 'examples/**/*.{rb,nonofs}',
                 'spec/spec-fs.nonofs',
                 'scripts/protocol-scanner']
require 'sg/rake/tasks'

desc 'Generate the protocol message structures.'
task 'generate' => [ 'lib/nonop/protocol/messages.rb' ]

directory 'lib/nonop/protocol'
file 'lib/nonop/protocol/messages.rb' =>
  [ 'doc/protocol.md',
    'scripts/protocol-scanner',
    'lib/nonop/protocol' ] do |t|
  sh("scripts/protocol-scanner doc/protocol.md > #{t.name}")
end
