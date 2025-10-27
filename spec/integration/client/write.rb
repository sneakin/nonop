require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'Twrite in append mode' do
  |state:, at:, contents:|

  describe 'in append mode' do
    let(:io) { attachment.open(at, flags: :APPEND) }
    let(:txt) { 'This is a test.' }

    before do
      expect { io.wait }.to change(io, :ready?).to be(true)
    end

    describe 'after the write' do
      subject { io.write(txt) }

      it 'always writes at the end of file' do
        expect(subject).to eql(txt.bytesize) # nop
        attachment.open(at) do |rio|
          # expect(rio.read(contents.bytesize + txt.bytesize)).
          #  to eql(contents + txt)
          #rio.close
          rio.read(contents.bytesize + txt.bytesize) do |data|
            expect(data).to eql(contents + txt)
            rio.close
            #.wait # having this return a deferred value once mades
            # Value#accept go wonky
          end.wait
        end.wait
      end
      
      describe 'after more writes' do
      subject { 3.times.collect { io.write(txt) }.sum }

      it 'always writes at the end of file' do
          expect(subject).to eql(txt.bytesize * 3) # nop
          attachment.open(at) do |rio|
            expect(rio.read(contents.bytesize + txt.bytesize * 3)).
              to eql(contents + txt * 3)
            rio.close
          end.wait
        end
      end
    end
  end
end

shared_examples_for 'Twrite on a RW file' do
  |state:, at:, contents:|

  include ClientHelper

  describe 'walking to a file' do
    let(:io) { attachment.open(at, flags: :WRONLY) }
    
    describe 'not opened' do
      it 'errors' do
        expect(io).to_not be_ready
        expect { io.write('hello') }.to raise_error(NonoP::WriteError)
      end
    end
    describe 'and clunking' do
      before do
        io.wait.close.wait
      end
      
      it 'errors' do
        expect(io).to_not be_ready
        expect { io.write('hello') }.to raise_error(NonoP::RemoteIO::ClosedError)
      end
    end
    describe 'open for reading' do
      let(:io) { attachment.open(at) }

      before do
        expect { io.wait }.to change(io, :ready?).to be(true)
      end
      
      it 'errors' do
        expect { io.write('foo bar') }.to raise_error(NonoP::WriteError)
      end
    end

    describe 'open for writing' do
      let(:io) { attachment.open(at, flags: :WRONLY) }

      before do
        expect { io.wait }.to change(io, :ready?).to be(true)
      end

      describe 'file wrote in full' do
        let(:txt) { 'This is a test.' }

        subject { io.write(txt) }

        it 'returns with the number of bytes writen' do
          expect(subject).to eql(txt.bytesize)
        end

        it 'can be read back' do
          subject # nop
          expect(read_back(at, 128)).to eql(txt)
        end

        describe 'takes a block' do
          it 'returns a deferred value' do
            r = io.write(txt) do |cnt|
              expect(cnt).to eql(txt.bytesize)
              :ok
            end
            expect(r).to be_kind_of(SG::Defer::Waitable)
            expect(r.wait).to eql(:ok)
          end
          it 'can be read back' do
            io.write(txt) do |cnt|
              expect(cnt).to eql(txt.bytesize)
            end.wait
            expect(read_back(at, 128)).to eql(txt)
          end
        end
      end
      
      describe 'when using offsets' do
        let(:txt) { 'This is a test.' }
        
        before do
          (0...txt.bytesize).step(3) do |offset|
            expect(io.write(txt[offset, 3], offset: offset)).
              to eql(3)
          end
        end
        
        it 'can be read back' do
          expect(read_back(at, 128)).to eql(txt)
        end
      end
      
      describe 'write larger than max msglen' do
        let(:txt) { 'This is a test.' * 0xFFFF }

        subject { io.write(txt) }

        it 'can be read back' do # fixme
          subject # nop
          expect(attachment.open(at) do |rio|
                   (0...txt.bytesize).step(client.max_datalen).each do |offset|
                     expect(rio.read(client.max_datalen, offset: offset)).
                       to eql(txt[offset, client.max_datalen])
                   end
                   rio.close
                   :ok
                 end.wait).
            to eql(:ok)
          expect(attachment.open(at) do |rio|
                   expect { rio.read(txt.bytesize) }.to raise_error(ArgumentError)
                   # expect(rio.read(txt.bytesize)).to eql(txt)
                   rio.close
                   :ok
                 end.wait).
            to eql(:ok)
        end

        it 'splits into multiple Twrite'
        
        it 'adds the counts' do
          expect(subject).to eql(txt.size)
        end
        
        it 'stops on first error'
      end
    end

    it_should_behave_like('Twrite in append mode',
                          state: state,
                          at: at,
                          contents: contents)
  end
end

shared_examples_for 'Twrite on a RO file' do
  |state:, at:, contents:|

  include ClientHelper

  let(:io) { attachment.open(at) }

  before do
    expect { io.wait }.to change(io, :ready?).to be(true)
  end
  
  it 'errors' do
    expect { io.write('foo bar') }.to raise_error(NonoP::WriteError)
  end
end

shared_examples_for 'Twrite on a fifo' do
  |state:, at:, contents:|

  include ClientHelper

  it_should_behave_like('Twrite in append mode',
                        state: state,
                        at: at,
                        contents: '')
end

shared_examples_for 'Twrite on a directory' do
  |state:, at:|

  include ClientHelper

  let(:io) { attachment.open(at, flags: :DIRECTORY) }

  before do
    expect { io.wait }.to change(io, :ready?).to be(true)
  end
  
  it 'errors' do
    expect { io.write('foo bar') }.to raise_error(NonoP::WriteError)
  end
end

shared_examples_for 'server allowing Twrite' do
  |state:, paths:|

  include ClientHelper

  before do
    client.start
  end

  describe 'during auth' do
    before do
      expect(client.request(NonoP::L2000::Tauth.
                            new(afid: state.afid,
                                uname: NonoP::NString[state.username],
                                aname: NonoP::NString[state.aname],
                                n_uname: state.uid)).wait).
        to be_kind_of(NonoP::Rauth)
    end

    it 'is used to write to the afid' do
      client.request(NonoP::Twrite.
                     new(fid: state.afid,
                         offset: 0,
                         data: state.creds)) do |reply|
        expect(reply).to be_kind_of(NonoP::Rwrite)
        expect(reply.count).to eql(state.creds.bytesize)
      end.wait
    end
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

    with_options(state: state) do |w|
      w.it_should_behave_like 'Twrite on a RW file', **path_hash(paths.fetch(:rw))
      w.it_should_behave_like 'Twrite on a RO file', **path_hash(paths.fetch(:ro))
      if paths[:fifo]
        w.it_should_behave_like 'Twrite on a fifo', **path_hash(paths.fetch(:fifo))
      end
      w.it_should_behave_like 'Twrite on a directory', at: paths.fetch(:rwdir)
    end
  end
end

shared_examples_for 'server refusing Twrite' do
  |state:, paths:|

  include ClientHelper

  before do
    client.start
  end

  with_options(state: state) do |w|
    w.it_should_behave_like 'Twrite on a RO file', **path_hash(paths.fetch(:rw))
    w.it_should_behave_like 'Twrite on a RO file', **path_hash(paths.fetch(:ro))
  end
end
