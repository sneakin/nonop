require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tgetattr' do
  |state:|

  include ClientHelper
  
  it 'gets attributes on a fid'
end
