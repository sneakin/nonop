require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Twalk' do
  |state: ClientHelper.default_state,
   path: 'info/now',
   badpath: 'info/later'|

  include ClientHelper
  
  before do
    client.start
  end

  describe 'before auth' do
    it 'errors' do
      expect(client.request(NonoP::Twalk.new(fid: 0,
                                             newfid: 1,
                                             nwnames: 0,
                                             wnames: [])).wait).
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
    it 'errors using the afid' do
      expect(client.request(NonoP::Twalk.new(fid: state.afid,
                                             newfid: 1,
                                             nwnames: 0,
                                             wnames: [])).wait).
        to be_kind_of(NonoP::ErrorPayload)
    end
    it 'errors using 0 for the afid' do
      expect(client.request(NonoP::Twalk.new(fid: 0,
                                             newfid: 1,
                                             nwnames: 0,
                                             wnames: [])).wait).
        to be_kind_of(NonoP::ErrorPayload)
    end
  end

  describe 'after auth' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds).wait
    end

    describe 'before attach' do
      it 'errors using the afid' do
        expect(client.request(NonoP::Twalk.new(fid: state.afid,
                                               newfid: 1,
                                               nwnames: 0,
                                               wnames: [])).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
      it 'errors using 0 for the fid' do
        expect(client.request(NonoP::Twalk.new(fid: 0,
                                               newfid: 1,
                                               nwnames: 0,
                                               wnames: [])).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end

    describe 'after attach' do
      let(:attachment_fid) { 10 }
      
      before do
        client.request(NonoP::L2000::Tattach.
                       new(fid: attachment_fid,
                           afid: -1, # fixme use afid too
                           uname: NonoP::NString[state.username],
                           aname: NonoP::NString[state.aname],
                           n_uname: state.uid)) do |reply|
          expect(reply).to be_kind_of(NonoP::Rattach)
        end.wait
      end

      describe 'with no path' do
        it 'made a new fid' do
          client.request(NonoP::Twalk.new(fid: attachment_fid,
                                          newfid: 1,
                                          nwnames: 0,
                                          wnames: [])) do |pkt|
            expect(pkt).to be_kind_of(NonoP::Rwalk)
            expect(pkt.nwqid).to eql(0)
            expect(pkt.wqid).to be_empty
          end.wait
          expect(client.request(NonoP::Tclunk.new(fid: 1)).wait).
            to be_kind_of(NonoP::Rclunk)
        end          
      end
      describe 'with a good path' do
        let(:newfid) { rand(1000) }
        
        it 'made a new fid' do
          parts = path.split('/')
          client.request(NonoP::Twalk.new(fid: attachment_fid,
                                          newfid: newfid,
                                          wnames: parts.collect { NonoP::NString[_1] })) do |pkt|
            expect(pkt).to be_kind_of(NonoP::Rwalk)
            expect(pkt.nwqid).to eql(parts.size)
            expect(pkt.wqid.size).to eql(parts.size)
          end.wait
          expect(client.request(NonoP::Tclunk.new(fid: newfid)).wait).
            to be_kind_of(NonoP::Rclunk)
        end

        describe 'using a new fid' do
          let(:clonedfid) { rand(10000) }
          
          before do
            expect(client.request(NonoP::Twalk.new(fid: attachment_fid,
                                            newfid: newfid,
                                            wnames: [ NonoP::NString[path.split('/').first]
                                                    ])).wait).
              to be_kind_of(NonoP::Rwalk)
          end
          
          it 'clones' do
            client.request(NonoP::Twalk.new(fid: newfid,
                                            newfid: clonedfid,
                                            nwnames: 0,
                                            wnames: [])) do |pkt|
              expect(pkt).to be_kind_of(NonoP::Rwalk)
              expect(pkt.nwqid).to eql(0)
              expect(pkt.wqid.size).to eql(0)
            end.wait
            expect(client.request(NonoP::Tclunk.new(fid: clonedfid)).wait).
              to be_kind_of(NonoP::Rclunk)
            expect(client.request(NonoP::Tclunk.new(fid: newfid)).wait).
              to be_kind_of(NonoP::Rclunk)
          end
          
          it 'walks deeper' do
            parts = path.split('/')
            client.request(NonoP::Twalk.new(fid: newfid,
                                            newfid: clonedfid,
                                            wnames: parts[1..-1].collect { NonoP::NString[_1] })) do |pkt|
              expect(pkt).to be_kind_of(NonoP::Rwalk)
              expect(pkt.nwqid).to eql(parts.size - 1)
              expect(pkt.wqid.size).to eql(parts.size - 1)
            end.wait
            expect(client.request(NonoP::Tclunk.new(fid: clonedfid)).wait).
              to be_kind_of(NonoP::Rclunk)
            expect(client.request(NonoP::Tclunk.new(fid: newfid)).wait).
              to be_kind_of(NonoP::Rclunk)
          end
        end
      end

      describe 'with a non existing path' do
        let(:newfid) { rand(10000) }
        
        it 'walks to the parent that exists' do
          parts = badpath.split('/')
          client.request(NonoP::Twalk.new(fid: attachment_fid,
                                          newfid: newfid,
                                          wnames: parts.collect { NonoP::NString[_1] })) do |pkt|
            expect(pkt).to be_kind_of(NonoP::Rwalk)
            expect(pkt.nwqid).to eql(parts.size - 1)
            expect(pkt.wqid.size).to eql(parts.size - 1)
          end.wait
          expect(client.request(NonoP::Tclunk.new(fid: newfid)).wait).
            to be_kind_of(NonoP::Rclunk)
        end
      end
      describe 'with a disallowed path' do
        # todo need ACL and to use a user w/o access
        it 'errors'
      end
    end
  end
end
