require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Trename' do
  |state:|

  include ClientHelper

  it 'renames a file'
end

shared_examples_for 'server refusing Trename' do
  |state:|

  include ClientHelper

  it 'fail to rename a file'
end
