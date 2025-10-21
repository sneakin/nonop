require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tauth' do
  |state:|
  
  include ClientHelper
  
  let(:auth_opts) do
    { uname: state.username,
      n_uname: state.uid,
      aname: state.aname,
      credentials: state.creds
    }
  end

  describe 'before Tversion' do
    it 'errors' do
      expect { client.auth(**auth_opts).wait }.
        to raise_error(NonoP::AuthError)
    end
  end

  describe 'after Tversion' do
    before do
      client.start
    end
    
    describe 'valid user' do
      it 'sets up a fid' do
        client.auth(**auth_opts).wait
        att = client.auth_attachment_for(state.aname)
        expect { att.close.wait }.to_not raise_error
      end

      describe 'writing valid creds' do
        it 'authenticates' do
          expect { client.auth(**auth_opts).wait }.
            to change(client, :authenticated?)
          expect(client.authenticated_for?(state.aname)).to be(true)
        end
      end
      describe 'writing invalid creds' do
        it 'errors' do
          expect { client.auth(**auth_opts.merge(credentials: 'bob')).wait }.
            to raise_error(NonoP::AuthError)
          expect(client.authenticated?).to be(false)
          expect(client.authenticated_for?(state.aname)).to be(false)
        end
      end      
    end
    describe 'invalid aname' do
      it 'errors' do
        expect { client.auth(**auth_opts.merge(aname: 'bob')).wait }.
          to raise_error(NonoP::AuthError)
        expect(client.authenticated?).to be(false)
        expect(client.authenticated_for?(state.aname)).to be(false)
      end
    end
    describe 'invalid user' do
      it 'errors' do
        expect { client.auth(**auth_opts.merge(uname: 'bob')).wait }.
          to raise_error(NonoP::AuthError)
        expect(client.authenticated?).to be(false)
        expect(client.authenticated_for?(state.aname)).to be(false)
      end
    end
    describe 'invalid creds' do
      it 'errors' do
        expect { client.auth(**auth_opts.merge(credentials: 'bob')).wait }.
          to raise_error(NonoP::AuthError)
        expect(client.authenticated?).to be(false)
        expect(client.authenticated_for?(state.aname)).to be(false)
      end
    end
  end
end
