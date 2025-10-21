require 'sg/ext'
using SG::Ext

require_relative '../helper'

# todo server does not yet handle Tauth

shared_examples_for 'server allowing Tauth' do
  |state:|
  
  include ClientHelper
  
  let(:msg) do
    NonoP::Tauth.new(afid: 0,
                     uname: NonoP::NString.new(state.username),
                     aname: NonoP::NString.new(state.aname))
  end

  describe 'before Tversion' do
    it 'errors' do
      dv = client.request(msg) do |reply|
        expect(reply).to be_kind_of(NonoP::Rerror)
        :ok
      end
      expect(dv.wait).to eql(:ok)
    end
  end

  describe 'after Tversion' do
    before do
      client.request(NonoP::Tversion.new(version: NonoP::NString.new('9P2000.L'),
                                         msize: 1400))
    end
    
    describe 'valid user' do
      it 'sets up a fid' do
        dv = client.request(msg) do |reply|
          expect(reply).to be_kind_of(NonoP::Rauth)
          expect(reply.qid).to_not be_nil
          :ok
        end
        # expect(dv).to be_kind_of(SG::Defer::Waitable)
        expect(dv.wait).to eql(:ok)
      end

      describe 'writing valid creds' do
        it 'authenticates'
      end
      describe 'writing invalid creds' do
        it 'errors'
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
