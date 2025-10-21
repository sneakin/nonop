require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Tstatfs' do
  |state:|

  include ClientHelper

  describe 'after auth and attach' do
    describe 'client helper' do
      it 'gets info about the export'

      describe 'other exports' do
        it 'gets info about that export'
      end
    end
    
    it 'gets info about the export'

    describe 'other exports' do
      it 'gets info about that export'
    end
  end
end
