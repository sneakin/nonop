require 'sg/ext'
using SG::Ext

require_relative 'helper'

# fixme Server needs to delay user lookup errors until attach

shared_examples_for 'server allowing Tlauth' do
  |state: ClientHelper.default_state|
  
  include ClientHelper

  let(:msg) do
    NonoP::L2000::Tauth.new(afid: state.afid,
                            uname: NonoP::NString[state.username],
                            aname: NonoP::NString[state.aname],
                            n_uname: state.uid)
  end

  describe 'the client helper method' do
    it 'can be sychronous' do
      dv = nil
      expect {
        dv = client.auth(uname: state.username,
                         n_uname: state.uid,
                         aname: 'spec',
                         credentials: state.creds).wait
      }.to change(client, :authenticated?)
    end
    
    it 'authenticates asynchronously' do
      # todo Attachment#initialize needs to wait
      dv = nil
      expect {
        dv = client.auth(uname: state.username,
                         n_uname: state.uid,
                         aname: 'spec',
                         credentials: state.creds)
      }.to_not change(client, :authenticated?)
      expect { dv.wait }.to change(client, :authenticated?)
    end

    describe 'raises errors' do
      it 'for bad username'
      it 'for bad uid'
      it 'for bad aname'
      it 'for bad creds'
    end
  end

  describe 'before Tversion' do
    it 'errors' do
      dv = client.request(msg) do |reply|
        expect(reply).to be_kind_of(NonoP::L2000::Rerror)
        :ok
      end
      expect(dv.wait).to eql(:ok)
    end
  end

  describe 'after Tversion' do
    before do
      client.request(NonoP::Tversion.
                     new(version: NonoP::NString.new('9P2000.L'),
                         msize: 1400)).wait
    end
    
    describe 'valid user' do
      it 'sets up a fid' do
        dv = client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)
          expect(reply.aqid).to be_kind_of(NonoP::Qid)
          expect(reply.aqid.type).to eql(NonoP::Qid::Types[:AUTH])
          :ok
        end
        # expect(dv).to be_kind_of(SG::Defer::Waitable)
        expect(dv.wait).to eql(:ok)
      end

      describe 'writing valid creds' do
        # todo multiple small writes...a reason why to delay for action on attach
        it 'authenticates' do
          client.request(msg) do |reply|
            expect(reply).to be_kind_of(NonoP::Rauth)
            client.request(NonoP::Twrite.new(fid: state.afid, offset: 0, data: state.creds)) do |reply|
              expect(reply).to be_kind_of(NonoP::Rwrite)
              expect(reply.count).to eql(state.creds.bytesize)
              
              client.request(NonoP::L2000::Tattach.
                             new(fid: 0,
                                 afid: state.afid,
                                 uname: NonoP::NString[state.username],
                                 aname: NonoP::NString[state.aname],
                                 n_uname: state.uid)) do |reply|
                expect(reply).to be_kind_of(NonoP::Rattach)
                client.request(NonoP::Tclunk.new(fid: state.afid)) do |reply1|
                  expect(reply1).to be_kind_of(NonoP::Rclunk)
                  expect(client.request(NonoP::Tclunk.new(fid: 0)) do |reply2|
                           expect(reply2).to be_kind_of(NonoP::Rclunk)
                           :wut
                         end.wait).to eql(:wut)
                end.wait
              end.wait
            end.wait
          end.wait
        end
      end
      
      describe 'writing invalid creds' do
        it 'errors' do
          client.request(NonoP::Twrite.new(fid: state.afid,
                                           offset: 0,
                                           data: state.creds + state.creds)) do |reply|
            expect(reply).to be_kind_of(NonoP::Rwrite)
            expect(reply.count).to eql(state.creds.bytesize * 2)
            
            client.request(NonoP::L2000::Tattach.new(fid: 0,
                                                     afid: state.afid,
                                                     uname: NonoP::NString[state.username],
                                                     aname: NonoP::NString[state.aname],
                                                     n_uname: state.uid)) do |reply|
              expect(reply).to be_kind_of(NonoP::L2000::Rerror)
              :wut
            end.wait
          end.wait
        end          
      end      
    end
    
    describe 'invalid aname' do
      it 'sets up a fid' do
        msg.aname = NonoP::NString['boom']
        dv = client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)
          expect(reply.aqid).to be_kind_of(NonoP::Qid)
          expect(reply.aqid.type).to eql(NonoP::Qid::Types[:AUTH])
          :ok
        end
        # expect(dv).to be_kind_of(SG::Defer::Waitable)
        expect(dv.wait).to eql(:ok)
      end

      it 'errors after write / on attach' do
        msg.aname = NonoP::NString['boom']
        client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)

          client.request(NonoP::Twrite.new(fid: state.afid,
                                           offset: 0,
                                           data: state.creds)) do |reply|
            expect(reply).to be_kind_of(NonoP::Rwrite)
            expect(reply.count).to eql(state.creds.bytesize)
            
            client.request(NonoP::L2000::Tattach.new(fid: 0,
                                                     afid: state.afid,
                                                     uname: NonoP::NString[state.username],
                                                     aname: msg.aname,
                                                     n_uname: state.uid)) do |reply|
              expect(reply).to be_kind_of(NonoP::L2000::Rerror)
            end.wait
          end.wait
        end.wait
      end
    end
    
    describe 'invalid user' do
      it 'sets up a fid' do
        msg.uname = NonoP::NString['boom']
        dv = client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)
          expect(reply.aqid).to be_kind_of(NonoP::Qid)
          expect(reply.aqid.type).to eql(NonoP::Qid::Types[:AUTH])
          :ok
        end
        # expect(dv).to be_kind_of(SG::Defer::Waitable)
        expect(dv.wait).to eql(:ok)
      end

      it 'errors after write / on attach' do
        msg.uname = NonoP::NString['boom']
        client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)

          client.request(NonoP::Twrite.new(fid: state.afid,
                                           offset: 0,
                                           data: state.creds)) do |reply|
            expect(reply).to be_kind_of(NonoP::Rwrite)
            expect(reply.count).to eql(state.creds.bytesize)
            
            client.request(NonoP::L2000::Tattach.new(fid: 0,
                                                     afid: state.afid,
                                                     uname: msg.uname,
                                                     aname: NonoP::NString[state.aname],
                                                     n_uname: state.uid)) do |reply|
              expect(reply).to be_kind_of(NonoP::L2000::Rerror)
            end.wait
          end.wait
        end.wait
      end
    end

    describe 'invalid uid' do
      it 'sets up a fid' do
        msg.n_uname = state.uid / 2
        dv = client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)
          expect(reply.aqid).to be_kind_of(NonoP::Qid)
          expect(reply.aqid.type).to eql(NonoP::Qid::Types[:AUTH])
          :ok
        end
        # expect(dv).to be_kind_of(SG::Defer::Waitable)
        expect(dv.wait).to eql(:ok)
      end

      it 'errors after write / on attach' do
        msg.n_uname = state.uid / 2
        client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::L2000::Rauth)

          client.request(NonoP::Twrite.new(fid: state.afid,
                                           offset: 0,
                                           data: state.creds)) do |reply|
            expect(reply).to be_kind_of(NonoP::Rwrite)
            expect(reply.count).to eql(state.creds.bytesize)
            
            client.request(NonoP::L2000::Tattach.new(fid: 0,
                                                     afid: state.afid,
                                                     uname: NonoP::NString[state.username],
                                                     aname: NonoP::NString[state.aname],
                                                     n_uname: state.uid / 2)) do |reply|
              expect(reply).to be_kind_of(NonoP::L2000::Rerror)
            end.wait
          end.wait
        end.wait
      end
    end
  end
end
