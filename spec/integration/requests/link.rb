require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tlink' do
  |state:|

  include ClientHelper

  it 'hard links a fid'
end

shared_examples_for 'server refusing Tlink' do
  |state:|

  include ClientHelper

  it 'refuses to hard link'
end
