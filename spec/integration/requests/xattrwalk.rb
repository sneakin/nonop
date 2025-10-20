require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Txattrwalk' do
  |state:|

  include ClientHelper

  it 'gets xattrs on a fid'
end
