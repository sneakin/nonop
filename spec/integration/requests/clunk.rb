require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tclunk' do
  |state: ClientHelper.default_state|

  include ClientHelper
  
  before do
    client.start
  end

  describe 'before auth' do
    it 'errors' do
      expect(client.request(NonoP::Tclunk.new(fid: 0)).wait).
        to be_kind_of(NonoP::ErrorPayload) # todo Rerror until Tversion
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
        expect(client.request(NonoP::Tclunk.new(fid: state.afid)).wait).
          to be_kind_of(NonoP::Rclunk)
      end
      
      it 'disconnects' do
        expect { client.request(NonoP::Tclunk.new(fid: state.afid)).wait }.
          to change(client, :closed?).to eql(true)
      end
    end
    describe 'any other' do
      it 'errors' do
        expect(client.request(NonoP::Tclunk.new(fid: 789)).wait).
          to be_kind_of(NonoP::ErrorPayload)
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
        expect(client.request(NonoP::Tclunk.new(fid: attachment_fid)).wait).
          to be_kind_of(NonoP::Rclunk)
      end

      it 'can not clunk the afid' do
        expect(client.request(NonoP::Tclunk.new(fid: state.afid)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end

      it 'errors on other fids' do
        expect(client.request(NonoP::Tclunk.new(fid: 789)).wait).
          to be_kind_of(NonoP::ErrorPayload)
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
          expect(client.request(NonoP::Tclunk.new(fid: 2)).wait).
            to be_kind_of(NonoP::Rclunk)
        end

        it "clunks w/ the client's helper" do
          expect(client.clunk(2).wait).to be_kind_of(NonoP::Rclunk)
        end
      end

      describe 'after a walk to a file' do
        before do
          expect(client.request(NonoP::Twalk.
                                new(fid: attachment_fid,
                                    newfid: 2,
                                    nwnames: 0,
                                    wnames: [ NonoP::NString['info'],
                                              NonoP::NString['now']
                                            ])).wait).
            to be_kind_of(NonoP::Rwalk)
        end
        
        it 'can clunk the new fid' do
          expect(client.request(NonoP::Tclunk.new(fid: 2)).wait).
            to be_kind_of(NonoP::Rclunk)
        end

        it "clunks w/ the client's helper" do
          expect(client.clunk(2).wait).to be_kind_of(NonoP::Rclunk)
        end
      end
    end
  end
end
