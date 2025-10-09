require 'sg/ext'
using SG::Ext

require_relative '../spec-helper'

require 'nonop'
require 'munge'

# todo shared secret auth instead of munge

describe 'nonop server' do
  include NonoP::SpecHelper

  YOU = ENV.fetch('USER')
  
  def self.raises_when cond, ex, &fn
    if !cond
      it { expect { instance_eval(&fn) }.to_not raise_error }
    else
      it { expect { instance_eval(&fn) }.to raise_error(ex) }
    end
  end

  describe 'spec acl' do
    before :all do
      @server, @started_at = start_server
    end

    after :all do
      stop_server(@server)
    end

    let(:sock) do
      TCPSocket.new('localhost', NonoP::SpecHelper::PORT)
    end
    let(:coder) do
      NonoP::L2000::Decoder.new
    end

    let(:client) do
      NonoP::Client.new(io: sock, coder: coder).tap do
        _1.start
      end
    end

    after do
      client.close
    end

    describe 'authenticating' do
      # fixme stop using the Yes backend to test bad users; only
      # exercising the ACL
      { YOU => [ Process.uid, true, true ],
        'alice' => [ nil, false, false ],
        'root' => [ 0, true, false ]
      }.each do |user, (uid, can_auth_ctl, can_auth_spec)|
        describe "as #{user}" do
          let(:auth_creds) { 'YES' }

          describe 'ctl' do
            raises_when(!can_auth_ctl, NonoP::AuthError) do
              client.auth(uname: user,
                          aname: 'ctl',
                          n_uname: uid || 0xBAD,
                          credentials: auth_creds)
            end
          end
          describe 'spec' do
            raises_when(!can_auth_spec, NonoP::AuthError) do
              client.auth(uname: user,
                          aname: 'spec',
                          n_uname: uid || 0xBAD,
                          credentials: auth_creds)
            end
          end
        end
      end

      describe "authorized against ctl as #{YOU}" do
        before do
          client.auth(uname: YOU,
                      aname: 'ctl',
                      n_uname: Process.uid,
                      credentials: auth_creds)
        end
        
        [[ YOU, Process.uid, true, false ],
         [ 'alice', nil, false, false ],
         [ 'alice', 0xBAD, false, false ],
         [ 'root', 0, false, false ]
        ].each do |(user, uid, can_attach_ctl, can_attach_spec)|
          describe "attaching as #{user} #{uid}" do
            let(:auth_creds) { 'YES' }

            describe 'spec' do
              raises_when(!can_attach_spec, NonoP::AttachError) do
                client.attach(uname: user,
                              n_uname: uid || 0,
                              aname: 'spec',
                              wait_for: true)
              end
            end
            describe 'ctl' do
              raises_when(!can_attach_ctl, NonoP::AttachError) do
                client.attach(uname: user,
                              n_uname: uid || 0,
                              aname: 'ctl',
                              wait_for: true)
              end
            end
          end
        end
      end
    end
  end
end
