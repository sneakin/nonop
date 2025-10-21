require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'Tlopen with good flags' do
  |flags:|

  flags.each do |flags|
    it "accepts #{flags.inspect}" do
      expect(client.request(NonoP::L2000::Topen.
                            new(fid: fid, flags: flags)).wait).
        to be_kind_of(NonoP::Ropen)
    end
  end
end

shared_examples_for 'Tlopen with bad flags' do
  |flags:|

  flags.each do |flags|
    it "errors opening with #{flags.inspect}" do
      expect(client.request(NonoP::L2000::Topen.
                            new(fid: fid, flags: flags)).wait).
        to be_kind_of(NonoP::ErrorPayload)
    end
  end
end

shared_examples_for 'server allowing Tlopen on a RW file' do
  |at:|

  describe "walking to #{at.inspect}" do
    let(:fid) { client.next_fid }
    
    before do
      expect(client.request(NonoP::Twalk.
                            new(fid: attachment_fid,
                                newfid: fid,
                                wnames: at.split('/').
                                  collect { NonoP::NString[_1] })).wait).
        to be_kind_of(NonoP::Rwalk)
    end
    
    it 'opens a file' do
      expect(client.request(NonoP::L2000::Topen.
                            new(fid: fid, flags: 0)).wait).
        to be_kind_of(NonoP::Ropen)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ :CREATE, :RDONLY, :WRONLY, :RDWR, :TRUNC, :APPEND ])
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :DIRECTORY ])
  end
end

shared_examples_for 'server allowing Tlopen on a new RW file' do
  |at:|

  describe "walking to #{at.inspect}" do
    let(:fid) { client.next_fid }
    
    before do
      expect(client.request(NonoP::Twalk.
                            new(fid: attachment_fid,
                                newfid: fid,
                                wnames: at.split('/').
                                  collect { NonoP::NString[_1] })).wait).
        to be_kind_of(NonoP::Rwalk)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :DIRECTORY, :WRONLY, :RDWR, :TRUNC, :APPEND].collect { [ _1, :CREATE ] })
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ 0, :DIRECTORY, :RDONLY, [:CREATE, :RDONLY], :WRONLY, :RDWR, :TRUNC, :APPEND] )
  end
end

shared_examples_for 'server refuses Tlopen write flags' do
  |at:|
  it_should_behave_like('Tlopen with bad flags',
                        flags: [ :WRONLY, :RDWR, :CREATE, :TRUNC, :APPEND ])
end

shared_examples_for 'server refusing Tlopen on a file' do
  |at:|

  describe "walking to #{at.inspect}" do
    let(:fid) { client.next_fid }
    
    before do
      expect(client.request(NonoP::Twalk.
                            new(fid: attachment_fid,
                                newfid: fid,
                                wnames: at.split('/').
                                  collect { NonoP::NString[_1] })).wait).
        to be_kind_of(NonoP::Rwalk)
    end

    it_should_behave_like('Tlopen with bad flags',
                          flags: [ 0, :DIRECTORY, :RDONLY, :RDWR ])
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen on a RO file' do
  |at:|

  describe "walking to #{at.inspect}" do
    let(:fid) { client.next_fid }
    
    before do
      expect(client.request(NonoP::Twalk.
                            new(fid: attachment_fid,
                                newfid: fid,
                                wnames: at.split('/').
                                  collect { NonoP::NString[_1] })).wait).
        to be_kind_of(NonoP::Rwalk)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :RDONLY ])
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :DIRECTORY ])
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen on a RO directory' do
  |at:|
  describe "walking to #{at.inspect}" do
    let(:fid) { client.next_fid }
    
    before do
      expect(client.request(NonoP::Twalk.
                            new(fid: attachment_fid,
                                newfid: fid,
                                wnames: at.split('/').
                                  collect { NonoP::NString[_1] })).wait).
        to be_kind_of(NonoP::Rwalk)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :DIRECTORY ])
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :RDONLY ])
    it_should_behave_like 'server refuses Tlopen write flags', at: at
  end
end

shared_examples_for 'server allowing Tlopen on a RW directory' do
  |at:|
  describe "walking to #{at.inspect}" do
    let(:fid) { client.next_fid }
    
    before do
      expect(client.request(NonoP::Twalk.
                            new(fid: attachment_fid,
                                newfid: fid,
                                wnames: at.split('/').
                                  collect { NonoP::NString[_1] })).wait).
        to be_kind_of(NonoP::Rwalk)
    end

    it_should_behave_like('Tlopen with good flags',
                          flags: [ 0, :DIRECTORY ])
    it_should_behave_like('Tlopen with bad flags',
                          flags: [ :RDONLY ])
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
      let(:attachment_fid) { 1 }
      before do
        expect(client.request(NonoP::L2000::Tattach.
                       new(fid: attachment_fid,
                           afid: -1,
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)).wait).
          to be_kind_of(NonoP::Rattach)
      end

      # todo UID & GID checks
      it_should_behave_like 'server refusing Tlopen on a file', at: paths.fetch(:noexist)
      it_should_behave_like 'server allowing Tlopen on a new RW file', at: paths.fetch(:noexist)
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
