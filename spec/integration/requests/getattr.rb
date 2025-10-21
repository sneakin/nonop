require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'allowed Tgetattr' do
  |at:, state:|

  describe "walked to #{at.inspect}" do
    describe 'full request mask' do
      it 'gets the attributes'
    end
    describe 'zero request mask' do
      it 'gets no attributes'
    end
    describe 'partial request mask' do
      it 'gets those attributes'
    end
  end
end

shared_examples_for 'server allowing Tgetattr' do
  |state:|

  include ClientHelper
  
  describe 'after auth and attach' do
    describe 'client helpers' do
      xit 'the below'
      it 'errors when no file exists'
    end
    
    it_should_behave_like 'allowed Tgetattr', at: 'info/ctl', state: state
    it_should_behave_like 'allowed Tgetattr', at: 'tmp/fifo', state: state
    it_should_behave_like 'allowed Tgetattr', at: 'info', state: state
  end
end
