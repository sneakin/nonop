require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'Tread on a file' do
  |at:, contents:, state:|

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
    
    describe 'not opened' do
      it 'errors' do
        expect(client.request(NonoP::Tread.
                              new(fid: fid, count: 32, offset: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end
    describe 'open for reading' do
      before do
        expect(client.request(NonoP::L2000::Topen.
                              new(fid: fid, flags: 0)).wait).
          to be_kind_of(NonoP::Ropen)
      end
      
      describe 'and closed' do
        before do
          client.clunk(fid)
        end
        
        it 'errors' do
          expect(client.request(NonoP::Tread.
                                new(fid: fid, count: 32, offset: 0)).wait).
            to be_kind_of(NonoP::ErrorPayload)
        end
      end
      describe 'file read in full' do
        it 'replies with the contents' do
          client.request(NonoP::Tread.
                                new(fid: fid, count: 32, offset: 0)) do |pkt|
            expect(pkt).to be_kind_of(NonoP::Rread)
            expect(pkt.count).to eql(contents.size)
            expect(pkt.data).to eql(contents)
          end.wait
        end
      end
      describe 'across small reads' do
        it 'reads every byte once' do
          data = ''
          offset = 0
          begin
            pkt = client.request(NonoP::Tread.
                                 new(fid: fid, count: 3, offset: offset)).wait
            expect(pkt).to be_kind_of(NonoP::Rread)
            data += pkt.data
            offset += 3
          end while pkt.count == 3
          expect(data).to eql(contents)
        end
      end
      describe 'read larger than max msglen' do
        it 'errors' do
          expect(client.request(NonoP::Tread.
                                new(fid: fid, count: 0xFFFFFFFF, offset: 0)).wait).
            to be_kind_of(NonoP::ErrorPayload)
        end
        xit 'but it could reply w/ multiple packets'
      end
    end
  end
end

shared_examples_for 'Tread on a write only file' do
  |at:, state:|
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

    describe 'open for write only' do
      before do
        expect(client.request(NonoP::L2000::Topen.
                              new(fid: fid, flags: :WRONLY)).wait).
          to be_kind_of(NonoP::Ropen)
      end
      it 'errors' do
        expect(client.request(NonoP::Tread.
                              new(fid: fid, count: 32, offset: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end
  end
end

shared_examples_for 'Tread on a fifo' do
  |at:, contents:, state:|
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

    describe 'open for appending reads' do
      before do
        expect(client.request(NonoP::L2000::Topen.
                              new(fid: fid, flags: [:APPEND, :RDONLY])).wait).
          to be_kind_of(NonoP::Ropen)
      end
      it 'ignores the offset' do
        c = "HEY HEY"
        2.times do
          contents.call(c)
          client.request(NonoP::Tread.
                         new(fid: fid, count: 32, offset: 4)) do |pkt|
            expect(pkt).to be_kind_of(NonoP::Rread)
            expect(pkt.count).to eql(c.size)
            expect(pkt.data).to eql(c)
          end.wait
        end
      end
    end
  end
end

shared_examples_for 'Tread on a directory' do
  |at:, state:|
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

    describe 'open as a directory' do
      before do
        expect(client.request(NonoP::L2000::Topen.
                              new(fid: fid, flags: :DIRECTORY)).wait).
          to be_kind_of(NonoP::Ropen)
      end
      it 'errors' do
        expect(client.request(NonoP::Tread.
                              new(fid: fid, count: 32, offset: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end
  end
end

shared_examples_for 'server allowing Tread' do
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
                      n_uname: state.uid).wait
      end
      let(:attachment_fid) { attachment.fid }

      with_options(state: state) do |w|
        w.it_should_behave_like 'Tread on a file', **path_hash(paths.fetch(:ro))
        w.it_should_behave_like 'Tread on a file', **path_hash(paths.fetch(:rw))
        w.it_should_behave_like 'Tread on a write only file', at: paths.fetch(:wo)
        if paths[:fifo]
          w.it_should_behave_like 'Tread on a fifo', **path_hash(paths.fetch(:fifo))
        end
        w.it_should_behave_like 'Tread on a directory', at: paths.fetch(:rodir)
        w.it_should_behave_like 'Tread on a directory', at: paths.fetch(:rwdir)
      end
    end
  end
end
