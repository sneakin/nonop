require 'sg/ext'
using SG::Ext

require_relative '../helper'

# todo uses L2000::Tattach

shared_examples_for 'server auths with Tattach' do
  |state: ClientHelper.default_state|
  
  include ClientHelper
  
  before do
    client.start
  end

  let(:attach_opts) {
    { aname: state.aname,
      uname: state.username,
      n_uname: state.uid
    }
  }
  
  describe 'before auth' do
    it 'errors' do
      expect { client.attach(**attach_opts).wait }.
        to raise_error(NonoP::AttachError)
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
    
    describe 'disallowed user' do
      it 'errors' do
        client.request(NonoP::Twrite.new(fid: state.afid, offset: 0, data: state.creds)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rwrite)
          expect(reply.count).to eql(state.creds.bytesize)

          expect {
            client.auth_attach(afid: state.afid,
                               uname: 'who',
                               aname: state.aname,
                               n_uname: state.uid).wait
          }.to raise_error(NonoP::AttachError)
        end
      end
    end

    describe 'allowed user' do
      it 'validates the creds' do
        client.request(NonoP::Twrite.
                       new(fid: state.afid,
                           offset: 0,
                           data: state.creds)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rwrite)
          expect(reply.count).to eql(state.creds.bytesize)
          
          expect {
            client.auth_attach(afid: state.afid,
                               uname: state.username,
                               aname: state.aname,
                               n_uname: state.uid).wait
          }.to_not raise_error
        end
      end
    end
  end
end

shared_examples_for 'server allowing Tattach' do
  |state: ClientHelper.default_state|

  include ClientHelper
  
  before do
    client.start
  end

  it_should_behave_like 'server auths with Tattach', state: state

  # fixme create actual ACL for the test
  describe 'after auth' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds)
    end
    
    describe 'disallowed username' do
      it 'errors' do
        expect {
          client.attach(afid: -1,
                        uname: 'bob',
                        aname: state.aname,
                        n_uname: state.uid).wait
        }.to raise_error(NonoP::AttachError)
      end
    end

    describe 'disallowed uid' do
      it 'errors' do
        expect {
          client.attach(afid: -1,
                        uname: state.username,
                        aname: state.aname,
                        n_uname: 124).wait
        }.to raise_error(NonoP::AttachError)
      end
    end

    describe 'allowed user' do
      it 'attached to the export' do
        att = client.attach(fid: 0,
                            afid: -1,
                            uname: state.username,
                            aname: state.aname,
                            n_uname: state.uid)
        att.wait
        expect(att).to be_ready
        expect { att.close }.to_not raise_error
      end
    end
  end
end

shared_examples_for 'server refusing Tattach' do
  |state: ClientHelper.default_state|

  include ClientHelper
  
  before do
    client.start
  end

  it_should_behave_like 'server auths with Tattach', state: state

  describe 'after auth' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds)
    end

    describe 'disallowed user' do
      it 'errors' do
        expect {
          client.attach(fid: 0,
                        afid: -1,
                        uname: 'bob',
                        aname: state.aname,
                        n_uname: state.uid).wait
        }.to raise_error(NonoP::AttachError)
      end
    end
    describe 'disallowed uid' do
      it 'errors' do
        expect {
          client.attach(fid: 0,
                        afid: -1,
                        uname: state.username,
                        aname: state.aname,
                        n_uname: 124).wait
        }.to raise_error(NonoP::AttachError)
      end
    end
    describe 'allowed user' do
      it 'errors' do
        expect {
          client.attach(fid: 0,
                        afid: -1,
                        uname: state.username,
                        aname: state.aname,
                        n_uname: state.uid).wait
        }.to raise_error(NonoP::AttachError)
      end
    end
  end
end
