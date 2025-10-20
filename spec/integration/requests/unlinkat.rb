require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tunlinkat' do
  |state:|

  include ClientHelper

  it 'removes a file'
end

shared_examples_for 'server refusing Tunlinkat' do
  |state:|

  include ClientHelper

  it 'fail to remove a file'
end
