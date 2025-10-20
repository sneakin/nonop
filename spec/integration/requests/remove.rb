require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tremove' do
  |state:|

  include ClientHelper

  it 'removes a file'
end

shared_examples_for 'server refusing Tremove' do
  |state:|

  include ClientHelper

  it 'keeps the file'
end
