require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tsetattr' do
  |state:|

  include ClientHelper

  it 'sets attributes on a fid'
end

shared_examples_for 'server refusing Tsetattr' do
  |state:|

  include ClientHelper

  it 'fails to set attributes on a fid'
end
