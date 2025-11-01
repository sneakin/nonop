require 'sg/ext'
using SG::Ext

require_relative 'helper'

describe 'server exporting a RW DirectoryEntry via a HashFileSystem' do
  include NonoP::SpecHelper
  include ClientHelper
  
  state = ClientHelper.default_state
  paths = {
    noexist: 'tmp/noexist',
    rw: [ 'scratch', '' ],
    ro: [ 'welcome', "Hello!\n" ],
    wo: 'tmp/writes',
    fifo: nil,
    rwdir: 'tmp',
    rodir: 'info'
  }
  
  before :all do
    this_file = Pathname.new(__FILE__)
    @path = this_file.
      parent.parent.parent.parent.
      join('spec', 'spec-fs.nonofs')
    @tmpdir = this_file.parent.parent.parent.parent.join('tmp')
    expect(@path).to be_exist
    @server, now = start_server('-e', "spec:#{@path}:rw")
  end
  after :all do
    stop_server
  end  

  with_options(state: state) do |w|
    w.it_should_behave_like 'server allowing Tversion'
    w.it_should_behave_like 'server refusing Tversion'
    # w.it_should_behave_like 'server allowing Tauth'
    w.it_should_behave_like 'server allowing Tlauth'
    w.it_should_behave_like 'server allowing Tattach'
    w.it_should_behave_like 'server allowing Tclunk'

    w.it_should_behave_like 'server allowing Twalk', path: paths.fetch(:rw)[0], badpath: paths.fetch(:noexist)[0]
    w.it_should_behave_like('server allowing Tlopen', paths: paths)
    w.it_should_behave_like 'server allowing Tread', paths: paths
    w.it_should_behave_like 'server allowing Twrite', paths: paths
    w.it_should_behave_like 'server allowing Tstatfs', stats: { type: 0x01021997, bsize: 4096, namelen: 255 }

    if SPEC_DRIVER != 'client'
      w.it_should_behave_like 'server allowing Topen'

      w.it_should_behave_like 'server allowing Tlcreate'

      w.it_should_behave_like 'server allowing Tflush'
      w.it_should_behave_like 'server allowing Tfsync'
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
end

describe 'server exporting a RO DirectoryEntry via a HashFileSystem' do
  include NonoP::SpecHelper
  include ClientHelper

  state = ClientHelper.default_state
  paths = {
    noexist: 'tmp/noexist',
    rw: [ 'scratch', '' ],
    ro: [ 'welcome', "Hello!\n" ],
    wo: 'tmp/writes',
    fifo: nil,
    rwdir: 'tmp',
    rodir: 'info'
  }
  
  before :all do
    @path = Pathname.new(__FILE__).
      parent.parent.parent.parent.
      join('spec', 'spec-fs.nonofs')
    expect(@path).to be_exist
    @server, now = start_server('-e', "spec:#{@path}:ro")
  end
  after :all do
    stop_server
  end

  with_options(state: state) do |w|
    w.it_should_behave_like 'server allowing Tversion'
    # w.it_should_behave_like 'server allowing Tauth'
    w.it_should_behave_like 'server allowing Tlauth'
    w.it_should_behave_like 'server allowing Tattach'
    w.it_should_behave_like 'server allowing Tclunk'

    w.it_should_behave_like 'server allowing Twalk'
    w.it_should_behave_like 'server allowing Tlopen', paths: paths
    w.it_should_behave_like 'server allowing Tread', paths: paths

    if SPEC_DRIVER != 'client'
      w.it_should_behave_like 'server allowing Topen'
      w.it_should_behave_like 'server refusing Tlcreate'
      w.it_should_behave_like 'server refusing Twrite'
      w.it_should_behave_like 'server allowing Tflush'
      w.it_should_behave_like 'server allowing Tfsync'
      w.it_should_behave_like 'server allowing Tstatfs'
      w.it_should_behave_like 'server allowing Tgetattr'
      w.it_should_behave_like 'server refusing Tsetattr'
      w.it_should_behave_like 'server allowing Tlock'
      w.it_should_behave_like 'server allowing Tgetlock'
      w.it_should_behave_like 'server refusing Trename'
      w.it_should_behave_like 'server refusing Trenameat'
      w.it_should_behave_like 'server refusing Tremove'
      w.it_should_behave_like 'server refusing Tunlinkat'
      w.it_should_behave_like 'server refusing Tlink'
      w.it_should_behave_like 'server refusing Tsymlink'
      w.it_should_behave_like 'server allowing Treadlink'
      w.it_should_behave_like 'server refusing Tmkdir'
      w.it_should_behave_like 'server allowing Treaddir'
      w.it_should_behave_like 'server refusing Tmknod'
      w.it_should_behave_like 'server refusing Txattrcreate'
      w.it_should_behave_like 'server allowing Txattrwalk'
    end
  end
end
