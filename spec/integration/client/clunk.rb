require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tclunk' do
  |state: ClientHelper.default_state, path: 'info/now'|

  include ClientHelper
  
  before do
    client.start
  end

  describe 'before auth' do
    it 'errors' do
      expect(client.clunk(0).wait).
        to be_kind_of(NonoP::ClunkError) # todo Rerror until Tversion
    end
  end

  describe 'during auth' do
    before do
      expect(client.request(NonoP::L2000::Tauth.
                            new(afid: state.afid,
                                uname: NonoP::NString[state.username],
                                aname: NonoP::NString[state.aname],
                                n_uname: state.uid)).
             wait).to be_kind_of(NonoP::Rauth)
    end
    
    describe 'the afid' do
      it 'destroys the fid' do
        expect(client.clunk(state.afid).wait).
          to be_kind_of(NonoP::Rclunk)
      end
      
      it 'disconnects' do
        expect { client.clunk(state.afid).wait }.
          to change(client, :closed?).to eql(true)
      end
    end
    describe 'any other' do
      it 'errors' do
        expect(client.clunk(789).wait).
          to be_kind_of(NonoP::ClunkError)
      end
    end      
  end

  describe 'after auth' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds)
    end
    
    describe 'attached to an export' do
      let(:attachment_fid) { 10 }
      
      before do
        client.request(NonoP::L2000::Tattach.
                       new(fid: attachment_fid,
                           afid: -1, # todo exercise other afids
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rattach)
        end.wait
      end

      it 'can clunk the attachment' do
        expect(client.clunk(attachment_fid).wait).
          to be_kind_of(NonoP::Rclunk)
      end

      it 'can not clunk the afid' do
        expect(client.clunk(state.afid).wait).
          to be_kind_of(NonoP::ClunkError)
      end

      it 'errors on other fids' do
        expect(client.clunk(789).wait).
          to be_kind_of(NonoP::ClunkError)
      end

      describe 'after a walk nowhere' do
        before do
          expect(client.request(NonoP::Twalk.
                                new(fid: attachment_fid,
                                    newfid: 2,
                                    nwnames: 0,
                                    wnames: [])).wait).
            to be_kind_of(NonoP::Rwalk)
        end
        
        it 'can clunk the new fid' do
          expect(client.clunk(2).wait).
            to be_kind_of(NonoP::Rclunk)
        end
      end

      describe 'after a walk to a file' do
        before do
          expect(client.request(NonoP::Twalk.
                                new(fid: attachment_fid,
                                    newfid: 2,
                                    wnames: patt.split('/').collect { NonoP::NString[_1] })).wait).
            to be_kind_of(NonoP::Rwalk)
        end
        
        it 'can clunk the new fid' do
          expect(client.clunk(2).wait).
            to be_kind_of(NonoP::Rclunk)
        end
      end
    end
  end
end
