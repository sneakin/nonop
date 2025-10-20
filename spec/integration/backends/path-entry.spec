require 'sg/ext'
using SG::Ext

require_relative 'helper'

describe 'server exporting a RW PathEntry' do
  include NonoP::SpecHelper

  state = ClientHelper.default_state
  
  before do
    @path = Pathname.new(__FILE__).
      parent.parent.parent.parent.
      join('spec', 'spec-fs.nonofs')
      # join('tmp', 'spec', 'integration')
    expect(@path).to be_exist
    @server, now = start_server('-e', "spec:#{@path}:rw")
  end
  after do
    stop_server
  end

  with_options(state: state) do |w|
    w.it_should_behave_like 'server allowing Tversion'
    w.it_should_behave_like 'server refusing Tversion'

    w.it_should_behave_like 'server allowing Tlauth'
    #it_should_behave_like 'server allowing Tauth'
    w.it_should_behave_like 'server allowing Tattach'
    w.it_should_behave_like 'server allowing Tclunk'
    w.it_should_behave_like 'server allowing Twalk'
    w.it_should_behave_like 'server allowing Topen'
    w.it_should_behave_like 'server allowing Tlopen'
    w.it_should_behave_like 'server allowing Tlcreate'
    w.it_should_behave_like 'server allowing Tread'
    w.it_should_behave_like 'server allowing Twrite'
    w.it_should_behave_like 'server allowing Tflush'
    w.it_should_behave_like 'server allowing Tfsync'
    w.it_should_behave_like 'server allowing Tstatfs'
    w.it_should_behave_like 'server allowing Tgetattr'
    w.it_should_behave_like 'server allowing Tsetattr'
    w.it_should_behave_like 'server allowing Tlock'
    w.it_should_behave_like 'server allowing Tgetlock'
    w.it_should_behave_like 'server allowing Trename'
    w.it_should_behave_like 'server allowing Trenameat'
    w.it_should_behave_like 'server allowing Tremove'
    w.it_should_behave_like 'server allowing Tunlinkat'
    w.it_should_behave_like 'server allowing Tlink'
    w.it_should_behave_like 'server allowing Tsymlink'
    w.it_should_behave_like 'server allowing Treadlink'
    w.it_should_behave_like 'server allowing Tmkdir'
    w.it_should_behave_like 'server allowing Treaddir'
    w.it_should_behave_like 'server allowing Tmknod'
    w.it_should_behave_like 'server allowing Txattrcreate'
    w.it_should_behave_like 'server allowing Txattrwalk'
  end
end
