require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Treaddir' do
  |state:|

  include ClientHelper

  it 'reads a directory with a fid'
end
