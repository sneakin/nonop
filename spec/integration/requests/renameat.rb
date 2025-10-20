require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Trenameat' do
  |state:|

  include ClientHelper

  it 'renames a file'
end

shared_examples_for 'server refusing Trenameat' do
  |state:|

  include ClientHelper

  it 'fail to rename a file'
end
