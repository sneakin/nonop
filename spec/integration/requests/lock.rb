require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tlock' do
  |state:|

  include ClientHelper

  it 'locks a fid'
end
