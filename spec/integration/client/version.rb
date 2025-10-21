require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tversion' do
  |version: '9P2000.L', state:|
  
  include ClientHelper
  
  it 'gets the version' do
    expect { client.start }.to change(client, :server_info).
      to eql({ version: version, msize: 0xFFFF })
  end
end

shared_examples_for 'server refusing Tversion' do
  |version: '9P3030', state:|

  include ClientHelper

  it 'errors' do
    expect { client.start }.to raise_error(NonoP::StartError)
  end
end
