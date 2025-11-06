require 'sg/ext'
using SG::Ext

require 'timeout'

require_relative '../helper'

shared_examples_for 'Tread on a file' do
  |at:, contents:, state:|
  
  describe "walking to #{at.inspect}" do
    let(:io) { attachment.open(at) }
    
    describe 'not opened' do
      it 'errors' do
        expect(io).to_not be_ready
        expect { io.read(16) }.to raise_error(NonoP::ReadError)
      end
    end
    
    describe 'opening and closing' do
      before do
        io.wait.close.wait
      end

      it 'errors on read' do
        expect { io.read(16) }.to raise_error(NonoP::RemoteIO::ClosedError)
      end
    end
    
    describe 'open for reading' do
      before do
        expect { io.wait }.to_not raise_error
      end
      
      describe 'file read in full' do
        it 'replies with the contents' do
          expect(io.read(32000)).to eql(contents)
        end
      end
      describe 'across small reads' do
        it 'reads every byte once' do
          offset = 0
          body = ''
          while data = io.read(3, offset: offset)
            break if data.size < 1
            body += data
            offset += 3
          end
          expect(body).to eql(contents)
        end
      end
      describe 'read larger than max msglen' do
        it 'reads what it can' do
          expect(io.read(0xFFFFFFFF)).to eql(contents)
        end
        
        xit 'but it could reply w/ multiple packets'
      end
      describe 'read past the end' do
        it 'replies with no data' do
          expect(io.read(32, offset: contents.size * 2)).to eql('')
        end
      end
    end
  end
end

shared_examples_for 'Tread on a write only file' do
  |at:, state:|
  describe "walking to #{at.inspect}" do
    let(:io) { attachment.open(at, flags: :WRONLY) }

    before do
      io.wait
    end
    
    it 'errors' do
      expect { io.read(32) }.to raise_error(ArgumentError)
    end      
  end
end

shared_examples_for 'Tread on a fifo' do
  |at:, contents:, state:|
  let(:io) { attachment.open(at, flags: [ :RDONLY, :APPEND ]) }

  describe "walking to #{at.inspect}" do
    before do
      io.wait
    end

    it 'does NOT block the server' do
      ok = true
      begin
        Timeout.timeout(1) do
          io.read(32, offset: 3) # does block
        end
      rescue Timeout::Error
        expect { attachment.open(at, flags: [ :RDONLY, :APPEND ]).wait }.
          to_not raise_error
        ok = true
      end
      expect(ok).to be(true)
    end
    
    it 'ignores the offset' do
      contents.call('hello')
      expect(io.read(32, offset: 3)).to eql('hello')
      contents.call('boom')
      expect(io.read(32, offset: 3)).to eql('boom')
    end      
  end
end

shared_examples_for 'Tread on a directory' do
  |at:, state:|
  let(:io) { attachment.open(at) }
  
  describe "walking to #{at.inspect}" do
    before do
      io.wait
    end

    it 'errors' do
      expect { io.read(32) }.to raise_error(NonoP::ReadError)
    end
  end
  
  describe '9p2000' do
    it 'uses Tread to read directories as files of Rstat dirents'
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

      with_options(state: state) do |w|
        w.it_should_behave_like 'Tread on a file', **path_hash(paths.fetch(:ro))
        w.it_should_behave_like 'Tread on a file', **path_hash(paths.fetch(:rw))
        w.it_should_behave_like 'Tread on a write only file', at: paths.fetch(:wo)
        # todo hov to fill the fifo w/ backend independence?
        if paths[:fifo]
          w.it_should_behave_like 'Tread on a fifo', **path_hash(paths.fetch(:fifo))
        end
        w.it_should_behave_like 'Tread on a directory', at: paths.fetch(:rodir)
        w.it_should_behave_like 'Tread on a directory', at: paths.fetch(:rwdir)
      end
    end
  end
end
