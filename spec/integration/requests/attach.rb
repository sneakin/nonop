require 'sg/ext'
using SG::Ext

require_relative 'helper'

# todo uses L2000::Tattach

shared_examples_for 'server auths with Tattach' do
  |state: ClientHelper.default_state|
  
  include ClientHelper
  
  before do
    client.start
  end

  describe 'before auth' do
    it 'errors' do
      client.request(NonoP::L2000::Tattach.
                     new(fid: 1,
                         afid: state.afid,
                         uname: NonoP::NString[state.username],
                         aname: NonoP::NString[state.aname],
                         n_uname: state.uid)) do |pkt|
        expect(pkt).to be_kind_of(NonoP::ErrorPayload)
      end.wait
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
          
          client.request(NonoP::L2000::Tattach.
                         new(fid: 0,
                             afid: state.afid,
                             uname: NonoP::NString['who'],
                             aname: NonoP::NString[state.aname],
                             n_uname: state.uid)) do |reply|
            expect(reply).to be_kind_of(NonoP::ErrorPayload)
          end.wait
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
          
          client.request(NonoP::L2000::Tattach.
                         new(fid: 0,
                             afid: state.afid,
                             uname: NonoP::NString[state.username],
                             aname: NonoP::NString[state.aname],
                             n_uname: state.uid)) do |reply|
            expect(reply).to be_kind_of(NonoP::Rattach)
          end.wait
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
        client.request(NonoP::L2000::Tattach.
                       new(fid: 0,
                           afid: -1,
                           uname: NonoP::NString['bob'],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rerror)
        end.wait
      end
    end

    describe 'disallowed uid' do
      it 'errors' do
        client.request(NonoP::L2000::Tattach.
                       new(fid: 0,
                           afid: -1,
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: 124)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rerror)
        end.wait
      end
    end

    describe 'allowed user' do
      it 'attached to the export' do
        client.request(NonoP::L2000::Tattach.
                       new(fid: 0,
                           afid: -1,
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rattach)
        end.wait
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
    describe 'disallowed user' do
      it 'errors' do
        client.request(NonoP::L2000::Tattach.
                       new(fid: 0,
                           afid: -1,
                           uname: NonoP::NString['bob'],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rerror)
        end.wait
      end
    end
    describe 'disallowed uid' do
      it 'errors' do
        client.request(NonoP::L2000::Tattach.
                       new(fid: 0,
                           afid: -1,
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: 124)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rerror)
        end.wait
      end
    end
    describe 'allowed user' do
      it 'errors' do
        client.request(NonoP::L2000::Tattach.
                       new(fid: 0,
                           afid: -1,
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rerror)
        end.wait
      end
    end
  end
end
