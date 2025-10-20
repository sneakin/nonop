require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tfsync' do
  |state:|

  include ClientHelper

  it 'syncs a fid'
end
