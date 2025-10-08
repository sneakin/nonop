require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'
require_relative '../remote-path'

module NonoP
  class RemoteIO
    attr_reader :client, :fid, :path

    def initialize client, fid, path
      @client = client
      @fid = fid
      @path = path
    end

    def close wait_for: false, &blk
      client.clunk(fid, wait_for:, &blk)
      self
    end

    # todo length limited to msglen
    # todo handling multiple replies for big reads
    def read length, offset: 0, &blk
      raise ArgumentError.new("Length %i must be 1...%i" % [ length, client.max_datalen ]) unless (1..client.max_datalen) === length
      raise ArgumentError.new("Offset must be positive") if offset < 0

      req = client.request(NonoP::Tread.new(fid: fid,
                                            offset: offset,
                                            count: length),
                           wait_for: blk == nil) do |result|
        blk&.call(wrap_error_or_data(result, ReadError))
      end

      if blk
        self
      else
        case req.data
        when Rread then return req.data.data
        when ErrorPayload then raise ReadError.new(req.data, path)
        else raise TypeError.new(req)
        end
      end
    end

    def write data, offset: 0, length: nil, wait_for: false, &blk
      raise ArgumentError.new("Offset must be positive") if offset < 0
      if data == nil
        if blk
          blk.call(nil)
          return self
        else
          return 0
        end
      end

      wait_for ||= blk == nil
      length ||= data.size
      block_size = client.max_datalen
      slices = NonoP.block_string(data, block_size, length: length)
      doner = lambda { |status, *a, **o, &b| status == true ? blk.call(*a, **o, &b) : blk.call(status, *a, **o, &b) }
      results = Async.reduce(slices, 0, offset) do |to_send, counter, offset, &cc|
        if to_send == nil || to_send.empty?
          cc.call(true, counter, offset, &blk)
          next
        end

        write_one(to_send, offset: offset, wait_for:) do |result|
          if StandardError === result
            cc.call(result, counter, offset, &doner)
          elsif result.count == to_send.bytesize
            cc.call(false, counter + result.count, offset + result.count, &doner)
          else
            cc.call(true, counter + result.count, offset + result.count, &doner)
          end
        end
      end

      if blk
        self
      else
        raise WriteError.new(err, path) if ErrorPayload === results
        return results[0]
      end
    end

    def write_one data, offset: 0, wait_for: false, &blk
      raise ArgumentError.new("Length %i must be 1...%i" % [ data.bytesize, client.max_datalen ]) unless (1..client.max_datalen) === data.bytesize
      raise ArgumentError.new("Offset must be positive") if offset < 0

      wait_for ||= blk == nil
      req = client.request(Twrite.new(fid: fid, offset: offset, data: data),
                           wait_for:) do |result|
        NonoP.maybe_call(blk, NonoP.maybe_wrap_error(result, WriteError))
      end

      if wait_for
        StandardError === req ? raise(req) : req.data.count
      else
        self
      end
    end

    def wrap_error_or_data pkt, error = Error
      case pkt
      when ErrorPayload then error.new(pkt, path)
      else pkt.data
      end
    end
  end
end
