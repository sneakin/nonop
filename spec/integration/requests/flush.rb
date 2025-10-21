require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tflush' do
  |state:|

  include ClientHelper
  
  it 'cancels a request'
end
