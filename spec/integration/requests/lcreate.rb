require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tlcreate' do
  |state:|

  include ClientHelper

  it 'creates a file with a fid'
end

shared_examples_for 'server refusing Tlcreate' do
  |state:|

  include ClientHelper

  it 'refuses to a file'
end
