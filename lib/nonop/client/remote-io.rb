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

    def close &blk
      client.clunk(fid, &blk)
    end

    # todo length limited to msglen
    # todo handling multiple replies for big reads
    def read length, offset: 0, &blk
      raise ArgumentError.new("Length %i must be 1...%i" % [ length, client.max_datalen ]) unless (1..client.max_datalen) === length
      raise ArgumentError.new("Offset must be positive") if offset < 0

      client.request(NonoP::Tread.new(fid: fid,
                                      offset: offset,
                                      count: length)) do |pkt|
        if ErrorPayload === pkt
          NonoP.maybe_call(blk, ReadError.new(pkt))
        else
          NonoP.maybe_call(blk, pkt.data)
        end
      end.skip_unless(blk == nil).wait
    end

    def write data, offset: 0, length: nil, &blk
      raise ArgumentError.new("Offset must be positive") if offset < 0

      # Multiple write requests can made. They're collected
      # and reduced to a total byte count and any errors.
      requests = NonoP::Client::PendingRequests.new(client).
        after do |results|
        results.reduce([0, []]) do |(total, errs), pkt|
          if ErrorPayload === pkt
            [ total, errs << pkt ]
          else
            [ total + pkt.count, errs ]
          end
        end.then { NonoP.maybe_call(blk, *_1) }
      end

      data ||= ''
      length ||= data.size
      block_size = client.max_datalen
      # Write the data out block by block:
      requests = NonoP.block_string(data, block_size, length: length).
        reduce(requests) do |acc, to_send|
        next acc if to_send == nil || to_send.empty?
        acc << write_one(to_send, offset: offset)
      end

      if blk
        requests
      else
        total, errs = requests.wait
        raise errs.first unless errs.empty?
        return total
      end
    end

    def write_one data, offset: 0, &blk
      raise ArgumentError.new("Length %i must be 1...%i" % [ data.bytesize, client.max_datalen ]) unless (1..client.max_datalen) === data.bytesize
      raise ArgumentError.new("Offset must be positive") if offset < 0

      client.request(Twrite.new(fid: fid, offset: offset, data: data)) do |pkt|
        if ErrorPayload === pkt
          NonoP.maybe_call(blk, WriteError.new(pkt))
        else
          NonoP.maybe_call(blk, pkt.count)
        end
      end
    end
  end
end
