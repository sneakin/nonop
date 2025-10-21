require 'sg/ext'
using SG::Ext

require_relative '../helper'

# fixme Server needs to delay user lookup errors until attach
# todo Client only uses Tlauth and this is duplicated in auth.rb.; could and should test a non-9p2000.L auth.

shared_examples_for 'server allowing Tlauth' do
  |state: ClientHelper.default_state|
  
  include ClientHelper

  let(:auth_opts) do
    { uname: state.username,
      n_uname: state.uid,
      aname: state.aname,
      credentials: state.creds
    }
  end

  describe 'after start' do
    before do
      client.start
    end
    
    it 'can be sychronous' do
      dv = nil
      expect {
        dv = client.auth(uname: state.username,
                         n_uname: state.uid,
                         aname: state.aname,
                         credentials: state.creds).wait
      }.to change(client, :authenticated?)
    end
    
    it 'authenticates asynchronously' do
      dv = nil
      expect {
        dv = client.auth(uname: state.username,
                         n_uname: state.uid,
                         aname: state.aname,
                         credentials: state.creds)
      }.to_not change(client, :authenticated?)
      expect { dv.wait }.to change(client, :authenticated?)
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
      it 'errors'
    end
    describe 'invalid user' do
      it 'errors'
    end
    describe 'invalid creds' do
      it 'errors'
    end
  end
end
