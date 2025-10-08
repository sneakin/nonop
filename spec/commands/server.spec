require 'sg/ext'
using SG::Ext

require_relative '../spec-helper'

require 'nonop'
require 'munge'

# todo shared secret auth instead of munge

describe 'nonop server' do
  include NonoP::SpecHelper
  
  describe 'spec acl' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    describe 'munge auth' do
      { ENV['USER'] => [ Process.uid, true, true ],
        'alice' => [ nil, false, false ],
        'root' => [ 0, true, false ]
      }.each do |user, (uid, can_attach_ctl, can_attach_spec)|
        describe "as #{user}" do
          let(:sock) do
            TCPSocket.new('localhost', NonoP::SpecHelper::PORT)
          end
          let(:coder) do
            NonoP::L2000::Decoder.new
          end
          
          let(:client) do
            NonoP::Client.new(io: sock, coder: coder).tap do
              _1.start
              auth_creds = Munge.encode(uid: uid)
              _1.auth(uname: user,
                      aname: 'spec',
                      n_uname: uid || 0xBAD,
                      credentials: auth_creds)
            end
          end

          if uid
            after do
              client.close
            end

            if can_attach_spec
              it 'can attach spec' do
                expect {
                  client.attach(uname: user, n_uname: uid, aname: 'spec', wait_for: true)
                }.to_not raise_error
              end
            else
              it 'can not attach spec' do
                expect {
                  client.attach(uname: user, n_uname: uid, aname: 'spec', wait_for: true)
                }.to raise_error(NonoP::AttachError) # todo Errno::EACCES
              end
            end
            if can_attach_ctl
              it 'can attach ctl' do
                expect {
                  client.attach(uname: user, n_uname: uid, aname: 'ctl', wait_for: true)
                }.to_not raise_error
              end
            else
              it 'can not attach ctl' do
                expect {
                  client.attach(uname: user, n_uname: uid, aname: 'ctl', wait_for: true)
                }.to raise_error(NonoP::AttachError) # todo Errno::EACCES
              end
            end
          else
            it { expect { client }.to raise_error(NonoP::AuthError) }
          end
        end
      end
    end
  end
end
