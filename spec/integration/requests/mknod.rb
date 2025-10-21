require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tmknod' do
  |state:|

  include ClientHelper

  it 'makes a device'
end

shared_examples_for 'server refusing Tmknod' do
  |state:|

  include ClientHelper

  it 'refuses to make a device'
end
