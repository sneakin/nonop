require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tversion' do
  |version: '9P2000.L', state:|
  
  include ClientHelper
  
  let(:msg) do
    NonoP::Tversion.new(version: NonoP::NString.new(version),
                        msize: 1400)
  end
  
  it 'returns the version' do
    dv = client.request(msg) do |reply|
      expect(reply).to be_kind_of(NonoP::Rversion)
      expect(reply.version.value).to eql(version)
      expect(reply.msize).to eql(0xFFFF) # todo match client? or server?
      :ok
    end
    # expect(dv).to be_kind_of(SG::Defer::Waitable)
    expect(dv.wait).to eql(:ok)
  end
end

shared_examples_for 'server refusing Tversion' do
  |version: '9P3030', state:|

  include ClientHelper

  let(:msg) do
    NonoP::Tversion.new(version: NonoP::NString.new(version),
                        msize: 1400)
  end
  
  it 'returns an error' do
    dv = client.request(msg) do |reply|
      expect(reply).to be_kind_of(NonoP::Rerror)
      :ok
    end
    # expect(dv).to be_kind_of(SG::Defer::Waitable)
    expect(dv.wait).to eql(:ok)
  end
end
