require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tmkdir' do
  |state:|

  include ClientHelper

  it 'creates a directory'
end

shared_examples_for 'server refusing Tmkdir' do
  |state:|

  include ClientHelper

  it 'creates a directory'
end
