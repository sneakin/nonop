require 'sg/ext'
using SG::Ext

require_relative '../helper'

shared_examples_for 'server allowing Twrite' do
  |state:, paths:|

  include ClientHelper

  describe 'during auth' do
    it 'is used to write to the afid'
  end
  
  describe 'after auth and attach' do
    describe 'client helpers' do
      describe 'walking to a file' do
        describe 'not opened' do
          it 'errors'
        end
        describe 'closed' do
          it 'errors'
        end
        describe 'open for writing' do
          describe 'file wrote in full' do
            it 'replies with the count'
          end
          describe 'across small writes' do
            it 'writes every byte once'
          end
          describe 'write larger than max msglen' do
            it 'splits into multiple Twrite'
            it 'adds the counts'
            it 'stops on first error'
          end
        end
        describe 'opened read only' do
          it 'errors'
        end
        describe 'fifo writes / append only' do
          it 'ignores the offset'
        end
        describe 'directory' do
          it 'errors'
        end
      end
    end
  
    describe 'walking to a file' do
      describe 'not opened' do
        it 'errors'
      end
      describe 'closed' do
        it 'errors'
      end
      describe 'open for writing' do
        describe 'file wrote in full' do
          it 'replies with the count'
        end
        describe 'across small writes' do
          it 'writes every byte once'
        end
        describe 'write larger than max msglen' do
          it 'errors'
        end
      end
      describe 'opened read only' do
        it 'errors'
      end
      describe 'fifo writes / append only' do
        it 'ignores the offset'
      end
      describe 'directory' do
        it 'errors'
      end
    end
  end
end

shared_examples_for 'server refusing Twrite' do
  |state:|

  include ClientHelper

  it 'refuses to write to a fid'
end
