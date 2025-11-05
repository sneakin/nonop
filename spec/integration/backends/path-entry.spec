require 'sg/ext'
using SG::Ext

require 'nonop/ext/statfs'
using NonoP::Ext::StatFS

require_relative 'helper'

describe 'server exporting a RW PathEntry' do
  include NonoP::SpecHelper

  state = ClientHelper.default_state
  Root = Pathname.new(__FILE__).parent.parent.parent.parent
  FSRoot = Root.join('tmp', 'spec', 'integration')
  Paths = {
    noexist: 'tmp/noexist',
    rw: [ 'tmp/huh', "huh\n" ],
    ro: [ 'info/now', Time.now.to_s ],
    wo: 'tmp/writes',
    fifo: [ 'tmp/fifo', lambda { |d| FSRoot.join('tmp/fifo').open('a+') { _1.write(d) } } ],
    rwdir: 'tmp',
    rodir: 'info'
  }
  
  before :all do
    @path = FSRoot
    expect(@path).to be_exist
    @server, now = start_server('-e', "spec:#{@path}:rw")
  end
  after :all do
    stop_server
  end

  before do
    setup_path
  end
  
  # fixme testing DirectoryEntry more so w/ the spec-fs; PathEntry hits real files. Paths to files need to be specified; test dir setup

  def cleanup_path
    @path.join('info').chmod(0700)
    @path.join('info', 'now').delete
    @path.rmtree
  end
    
  def setup_path
    cleanup_path if @path.exist?
    @path.mkdir
    @path.join('info').mkdir
    @path.join('tmp').mkdir
    @path.join('info', 'now').open('w') { _1.write(Paths.fetch(:ro)[1]) }
    @path.join('info', 'now').chmod(0400)
    @path.join('tmp', 'huh').open('w') { _1.write(Paths.fetch(:rw)[1]) }
    File.mkfifo(@path.join('tmp', 'fifo'))
    @path.join('tmp/symlink').make_symlink('../info/now')
    @path.join('tmp/link').make_link(@path.join('info/now'))
    @path.join('info').chmod(0544)
  end
  
  with_options(state: state) do |w|
    w.it_should_behave_like 'server allowing Tversion'
    w.it_should_behave_like 'server refusing Tversion'

    #w.it_should_behave_like 'server allowing Tauth'
    w.it_should_behave_like 'server allowing Tlauth'
    w.it_should_behave_like 'server allowing Tattach'
    w.it_should_behave_like 'server allowing Tclunk'

    w.it_should_behave_like 'server allowing Twalk', path: Paths.fetch(:rw)[0], badpath: Paths.fetch(:noexist)[0]
    w.it_should_behave_like('server allowing Tlopen', paths: Paths)
    w.it_should_behave_like 'server allowing Tread', paths: Paths
    w.it_should_behave_like 'server allowing Twrite', paths: Paths
    w.it_should_behave_like('server allowing Tstatfs',
                            stats: File.statfs(Paths.fetch(:rw)[0]),
                            ctl_stats: {})
    w.it_should_behave_like('server allowing Treaddir',
                            paths: Paths,
                            entries: {
                              rwdir: Pathname.new(FSRoot.join(Paths.fetch(:rwdir))).entries.collect(&:basename).collect(&:to_s).reject(&/^[.]{1,2}$/),
                              root: FSRoot.entries.collect(&:basename).collect(&:to_s).reject(&/^[.]{1,2}$/)
                            })
    
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

      w.it_should_behave_like 'server allowing Tmknod'
      w.it_should_behave_like 'server allowing Txattrcreate'
      w.it_should_behave_like 'server allowing Txattrwalk'
    end
  end
end
