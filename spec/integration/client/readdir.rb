require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Treaddir' do
  |state:|

  include ClientHelper

  describe 'after auth and attach' do
    describe 'client helpers' do
    end
    
    describe 'walking to a directory' do
      describe 'before open' do
        it 'errors'
      end

      describe 'after open' do
        describe 'full readdir' do
          it 'replies with all the entries'
        end
        describe 'split into multiple requests'
        it 'replies with all the entries once'
      end
    end

    describe 'on a file' do
      it 'errors'
    end

    describe 'on a made up fid' do
      it 'errors'
    end
  end
end
