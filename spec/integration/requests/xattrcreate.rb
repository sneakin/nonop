require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Txattrcreate' do
  |state:|

  include ClientHelper

  it 'creates xattrs on a fid'
end

shared_examples_for 'server refusing Txattrcreate' do
  |state:|

  include ClientHelper

  it 'refuses to create xattrs on a fid'
end
