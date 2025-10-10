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
                                      count: length)) do |result|
        NonoP.maybe_call(blk, wrap_error_or_data(result, ReadError))
      end.skip_unless(blk == nil).wait
    end

    def write data, offset: 0, length: nil, &blk
      raise ArgumentError.new("Offset must be positive") if offset < 0

      # Multiple write requests can made. They're collected
      # and reduced to a total byte count and any errors.
      requests = NonoP::Client::PendingRequests.new(client).
        after do |results|
        results.reduce([0, []]) do |(total, errs), cnt|
          if StandardError === cnt
            [ total, errs << cnt ]
          else
            [ total + cnt, errs ]
          end
        end.tap { blk&.call(*_1) }
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

      NonoP.vputs { "write one #{data.size}" }
      client.request(Twrite.new(fid: fid, offset: offset, data: data)) do |result|
        NonoP.vputs { "write_one done #{result}" }
        if blk
          blk.call(NonoP.maybe_wrap_error(result, WriteError))
        else
          ErrorPayload === result ? raise(result) : result.count
        end
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
