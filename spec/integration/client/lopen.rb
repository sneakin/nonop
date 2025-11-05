require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'Tlopen with good flags' do
  |at:, flags:|

  flags.each do |flags|
    it "accepts #{flags.inspect}" do
      expect(rio = attachment.open(at, flags: flags).wait).
        to be_kind_of(NonoP::RemoteFile)
      expect(rio).to be_ready
      expect((0..client.max_datalen).include?(rio.iounit)).to be_truthy
    end
  end
end

shared_examples_for 'Tlopen with bad flags' do
  |at:, flags:|

  flags.each do |flags|
    it "errors opening with #{flags.inspect}" do
      expect { attachment.open(at, flags: flags).wait }.
        to raise_error(NonoP::OpenError)
    end
  end
end

shared_examples_for 'server allowing Tlopen on a RW file' do
  |at:|

  describe "walking to #{at.inspect}" do
    before do
      expect(attachment.wait).to be(attachment)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :CREATE, :RDONLY, :WRONLY, :TRUNC, :APPEND],
                          at: at)
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :DIRECTORY ],
                          at: at)
  end
end

shared_examples_for 'server allowing Tlopen on a new RW file' do
  |at:|

  describe "walking to #{at.inspect}" do
    before do
      expect(attachment.wait).to be(attachment)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :CREATE, :WRONLY, :RDWR, :TRUNC, :APPEND],
                          at: at)

    it 'errors opening a file' do
      expect { attachment.open(at).wait }.to raise_error(NonoP::WalkError)
    end
    it 'errors opening as directory' do
      expect { attachment.open(at, flags: [:DIRECTORY]).wait }.to raise_error(NonoP::WalkError)
    end
    it 'error on reads' do
      expect { attachment.open(at, flags: :RDONLY).wait }.to raise_error(NonoP::WalkError)
    end
  end
end

shared_examples_for 'server refuses Tlopen write flags' do
  |at:|
  it_should_behave_like('Tlopen with bad flags',
                        flags: [ :WRONLY, :RDWR, :CREATE, :TRUNC, :APPEND ],
                        at: at)
end

shared_examples_for 'server refusing Tlopen on a file' do
  |at:|

  describe "walking to #{at.inspect}" do
    before do
      expect(attachment.wait).to be(attachment)
    end
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ 0, :DIRECTORY, :RDONLY, :RDWR ],
                          at: at)
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen on a RO file' do
  |at:|

  describe "walking to #{at.inspect}" do
    before do
      expect(attachment.wait).to be(attachment)
    end
    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :RDONLY ],
                          at: at)
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :DIRECTORY ],
                          at: at)
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen on a RO directory' do
  |at:|
  describe "walking to #{at.inspect}" do
    before do
      expect(attachment.wait).to be(attachment)
    end
    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :DIRECTORY ],
                          at: at)
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :RDONLY ],
                          at: at)
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen on a RW directory' do
  |at:|
  describe "walking to #{at.inspect}" do
    before do
      expect(attachment.wait).to be(attachment)
    end
    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :DIRECTORY ],
                          at: at)
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :RDONLY ],
                          at: at)
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen' do
  |state:, paths:|

  include ClientHelper

  describe 'after auth' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds)
    end
    
    describe 'and attach' do
      let(:attachment) do
        client.attach(afid: -1,
                      uname: state.username,
                      aname: state.aname,
                      n_uname: state.uid)
      end
      
      # todo UID & GID checks
      it_should_behave_like 'server refusing Tlopen on a file', at: paths.fetch(:noexist)
      # it_should_behave_like 'server allowing Tlopen on a new RW file', at: paths.fetch(:noexist)
      it_should_behave_like 'server allowing Tlopen on a RW file', at: paths.fetch(:rw)[0]
      if paths[:fifo]
        it_should_behave_like 'server allowing Tlopen on a RW file', at: paths.fetch(:fifo)[0]
      end
      it_should_behave_like 'server allowing Tlopen on a RO file', at: paths.fetch(:ro)[0]
      it_should_behave_like 'server allowing Tlopen on a RW directory', at: paths.fetch(:rwdir)
      it_should_behave_like 'server allowing Tlopen on a RO directory', at: paths.fetch(:rodir)
    end
  end
end
