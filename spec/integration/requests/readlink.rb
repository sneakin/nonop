require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Treadlink' do
  |state:|

  include ClientHelper

  it 'reads a symlink'
end
