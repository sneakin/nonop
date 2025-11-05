require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tstatfs' do
  |state:, stats:, ctl_stats:|

  include ClientHelper

  before do
    client.start
  end

  describe 'before auth' do
    it 'errors' do
      att = NonoP::Attachment.new(client: client,
                                  fid: 123,
                                  afid: -1,
                                  aname: state.aname,
                                  uname: state.username,
                                  n_uname: state.uid,
                                  qid: NonoP::Qid.new)
      r = nil
      expect { r = att.statfs }.to_not raise_error
      expect(r.wait).to be_kind_of(NonoP::ErrorPayload)
    end
  end

  describe 'after auth' do
    before do
      client.auth(uname: state.username,
                  aname: state.aname,
                  n_uname: state.uid,
                  credentials: state.creds)
    end

    describe 'before attach' do
      it 'errors with bad fd' do
        att = NonoP::Attachment.new(client: client,
                                    fid: 123,
                                    afid: -1,
                                    aname: state.aname,
                                    uname: state.username,
                                    n_uname: state.uid,
                                    qid: NonoP::Qid.new)
        r = nil
        expect { r = att.statfs }.to_not raise_error
        # expect { r.wait }.to raise_error(NonoP::ProtocolError) # todo better
        expect(r.wait).to be_kind_of(NonoP::ErrorPayload)
      end
    end
    
    describe 'after attach' do
      let(:attachment) do
        client.attach(afid: -1,
                      uname: state.username,
                      aname: state.aname,
                      n_uname: state.uid).wait
      end

      it 'returns a response' do
        expect(attachment.statfs).to be_kind_of(NonoP::Client::PendingRequest)
      end

      it 'gets info about the export' do
        expect(r = attachment.statfs.wait).to be_kind_of(NonoP::L2000::Rstatfs)
        stats.each.
          select { |k, _| r.respond_to?(k) }.
          each { expect(r.send(_1)).to eql(_2) }
      end

      describe 'other exports' do
        let(:ctl) do
          client.attach(afid: -1,
                        uname: state.username,
                        aname: 'ctl',
                        n_uname: state.uid).wait
        end

        describe 'before reauth' do
          it 'errors' do
            expect { ctl.statfs.wait }.to raise_error(NonoP::AttachError)
          end
        end

        describe 'after reauth' do
          before do
            # todo use new afid for attach?
            client.auth(uname: state.username,
                        aname: 'ctl',
                        n_uname: state.uid,
                        credentials: state.creds)
          end

          it 'returns a response' do
            expect(ctl.statfs).to be_kind_of(NonoP::Client::PendingRequest)
          end

          it 'gets info about the export' do
            expect(r = ctl.statfs.wait).to be_kind_of(NonoP::L2000::Rstatfs)
          end
        end
      end
      
      describe 'other fids' do
        it 'errors with bad fd' do
          att = NonoP::Attachment.new(client: client,
                                      fid: 123,
                                      afid: -1,
                                      aname: state.aname,
                                      uname: state.username,
                                      n_uname: state.uid,
                                      qid: NonoP::Qid.new)
          r = nil
          expect { r = att.statfs }.to_not raise_error
          # expect { r.wait }.to raise_error(NonoP::ProtocolError) # todo better
          expect(r.wait).to be_kind_of(NonoP::ErrorPayload)
        end
      end
    end
  end
end
