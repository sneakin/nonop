require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tread' do
  |state:|

  include ClientHelper

  it 'reads a file with a fid'
end
