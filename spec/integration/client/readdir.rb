require 'sg/is'
require 'sg/ext'
using SG::Ext

require_relative '../helper'

# todo wide and deep directories
# todo umode and ACL cases

shared_examples_for 'Treaddir on a directory' do
  |at:, entries:|

  describe "at #{at.inspect}" do
    describe 'before open' do
      it 'errors' do
        expect(client.request(NonoP::L2000::Treaddir.
                              new(fid: 0, count: 32, offset: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end

    describe 'opened as a file' do
      let(:io) do
        attachment.open(at, mode: 'r')
      end
      
      it 'errors' do
        io.wait
        expect(client.request(NonoP::L2000::Treaddir.
                              new(fid: io.fid, count: 32, offset: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end
    
    describe 'after open' do
      let(:io) do
        attachment.opendir(at)
      end
      describe 'entries' do
        it 'are enumerable' do
          expect(io.entries).to be_kind_of(Enumerable)
        end

        it 'enumerates the entries' do
          expect(io.entries.collect(&:name).collect(&:value)).
            to eql(entries)
        end
        
        describe 'split into multiple requests' do
          it 'replies with a count of entries' do
            expect(io.entries(count: 1).collect(&:name).collect(&:value)).
              to eql(entries[0, 1] || [])
          end
          it 'replies with entries from an offset' do
            expect(io.entries(offset: 1).collect(&:name).collect(&:value)).
              to eql(entries[1..-1] || [])
          end
          it 'replies with a count of entries from an offset' do
            expect(io.entries(count: 1, offset: 1).collect(&:name).collect(&:value)).
              to eql(entries[1, 1] || [])
          end
        end

        it 'yields the dirent of each entry to a block' do
          ents = []
          offset = 1
          io.entries {
            ents << _1
            expect(_1.offset).to eql(offset)
            offset += 1
          }
          expect(ents.all?(&SG::Is::CaseOf[NonoP::L2000::Rreaddir::Dirent])).
            to be(true)
          expect(ents.collect(&:name).collect(&:value)).to eql(entries)
        end
      end

      describe '#readdir' do
        it 'returns a request' do
          expect(io.readdir).to be_kind_of(NonoP::Client::PendingRequest)
        end
        
        it 'returns a request' do
          expect(io.readdir.wait).to be_kind_of(NonoP::L2000::Rreaddir)
        end
        
        describe 'readdir w/o size and offset' do
          it 'replies with a full message of entries' do
            ents = io.readdir.wait.entries
            NonoP.vputs { ents.inspect }
            expect(ents.collect(&:name).collect(&:value)).
              to eql(entries)
            expect(ents.collect(&:offset)).
              to eql(ents.size.times.collect { _1 + 1 }) # todo why +1?
          end
          it 'replies with a count of entries' do
            expect(io.readdir(1).wait.entries.
                   collect(&:name).collect(&:value)).
              to eql(entries[0, 1] || [])
          end
          it 'replies with entries from an offset' do
            ents = io.readdir(10, 1).wait.entries
            expect(ents.collect(&:name).collect(&:value)).
              to eql(entries[1, 10] || [])
            expect(ents.collect(&:offset)).
              to eql(ents.size.times.collect { _1 + 2 })
          end
          it 'replies with a count of entries from an offset' do
            expect(io.readdir(2, 1).wait.entries.
                   collect(&:name).collect(&:value)).
              to eql(entries[1, 2] || [])
          end
        end
      end
    end
  end
end

shared_examples_for 'server allowing Treaddir' do
  |state:, paths:, entries:|

  include ClientHelper

  before do
    client.start
  end

  describe 'after auth and attach' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds)
    end
    let(:attachment) do
      client.attach(afid: -1,
                    uname: state.username,
                    aname: state.aname,
                    n_uname: state.uid).wait
    end

    describe 'the attachment' do
      it_should_behave_like 'Treaddir on a directory', at: nil, entries: entries.fetch(:root)
      it_should_behave_like 'Treaddir on a directory', at: '', entries: entries.fetch(:root)
      it_should_behave_like 'Treaddir on a directory', at: '/', entries: entries.fetch(:root)
    end
    
    describe 'walking to a directory' do
      it_should_behave_like 'Treaddir on a directory', at: paths.fetch(:rwdir), entries: entries.fetch(:rwdir)
    end

    describe 'on a file' do
      [ [ :ro, NonoP::ReadError ],
        [ :rw, NonoP::ReadError ]
      ].collect { [ paths.fetch(_1[0])[0], _1[1] ] }.
        each do |path, err|
        it "that exists at #{path}, errors with #{err}" do
          expect { attachment.opendir(path).entries.to_a }.
            to raise_error(err)
        end
      end
    end

    describe 'on a made up fid' do
      it 'errors' do
        attachment.wait
        expect(client.request(NonoP::L2000::Treaddir.
                              new(fid: 123, count: 32, offset: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end
  end
end
