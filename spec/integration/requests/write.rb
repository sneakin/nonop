require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Twrite' do
  |state:|

  include ClientHelper

  it 'writes a file with a fid'
end

shared_examples_for 'server refusing Twrite' do
  |state:|

  include ClientHelper

  it 'refuses to write to a fid'
end
