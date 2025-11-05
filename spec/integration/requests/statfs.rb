require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tstatfs' do
  |state:, stats:, ctl_stats:|

  include ClientHelper

  describe 'before auth' do
    it 'gets info about that export' do
      expect(client.request(NonoP::L2000::Tstatfs.new(fid: 0)).wait).
        to be_kind_of(NonoP::ErrorPayload)
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
      it 'gets info about that export' do
        expect(client.request(NonoP::L2000::Tstatfs.new(fid: 0)).wait).
          to be_kind_of(NonoP::ErrorPayload)
      end
    end

    describe 'and attach' do
      let(:attachment) do
        client.attach(afid: -1,
                      uname: state.username,
                      aname: state.aname,
                      n_uname: state.uid).wait
      end

      describe 'on the attachment' do
        it 'gets info about the export' do
          req = client.request(NonoP::L2000::Tstatfs.new(fid: attachment.fid))
          expect(req).to be_kind_of(NonoP::Client::PendingRequest)
          req = req.wait
          expect(req).to be_kind_of(NonoP::L2000::Rstatfs)
          stats.each.
            select { |k, _| req.respond_to?(k) }.
            each { expect(req.send(_1)).to eql(_2) }          
        end
      end

      describe 'on a file' do
        let(:io) { attachment.open(paths.fetch(:ro)) }
        it "gets info about the file's host FS" do
          req = client.request(NonoP::L2000::Tstatfs.new(fid: attachment.fid))
          expect(req).to be_kind_of(NonoP::Client::PendingRequest)
          req = req.wait
          expect(req).to be_kind_of(NonoP::L2000::Rstatfs)
          stats.each.
            select { |k, _| req.respond_to?(k) }.
            each { expect(req.send(_1)).to eql(_2) }          
        end
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
            expect { client.request(NonoP::L2000::Tstatfs.new(fid: ctl.fid)).wait }.
              to raise_error(NonoP::AttachError)
          end
        end

        describe 'after reauth' do
          before do
            client.auth(uname: state.username,
                        aname: 'ctl',
                        n_uname: state.uid,
                        credentials: state.creds)
          end

          it 'gets info about that export' do
            req = client.request(NonoP::L2000::Tstatfs.new(fid: ctl.fid))
            expect(req).to be_kind_of(NonoP::Client::PendingRequest)
            req = req.wait
            expect(req).to be_kind_of(NonoP::L2000::Rstatfs)
            ctl_stats.each.
              select { |k, _| req.respond_to?(k) }.
              each { expect(req.send(_1)).to eql(_2) }          
          end
        end
      end
    end
  end
end
