require 'sg/ext'
using SG::Ext

module NonoP::Server::FileSystem
  # Provides a per connection interface to an Entry using a DataProvider to tailor the operations.
  class OpenedEntry
    # @return [Entry]
    attr_reader :entry
    # @return [Entry::DataProvider]
    attr_reader :data

    # @param entry [Entry]
    # @param data [Entry::DataProvider]
    def initialize entry, data
      @entry = entry
      @data = data
    end

    # @return [self]
    def close
      @data&.close
      @data = nil
      self
    end

    delegate :truncate, :read, :write, :readdir, :writeable?, :readable?, :appending?, to: :data

  end
end

