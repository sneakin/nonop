require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tstatfs' do
  |state:|

  include ClientHelper

  it 'gets info about the export'
end
