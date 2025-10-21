require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tgetlock' do
  |state:|

  include ClientHelper

  it 'checks for a lock'
end
