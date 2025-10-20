require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tlopen' do
  |state:|

  include ClientHelper

  it 'opens a file with a fid'
end
