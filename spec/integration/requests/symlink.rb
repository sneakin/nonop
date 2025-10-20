require 'sg/ext'
using SG::Ext

require_relative 'helper'

shared_examples_for 'server allowing Tsymlink' do
  |state:|

  include ClientHelper

  it 'symlinks a fid'
end

shared_examples_for 'server refusing Tsymlink' do
  |state:|

  include ClientHelper

  it 'refuses to symlink'
end
