require 'sg/ext'
using SG::Ext

require_relative '../async'
require_relative '../util'
require_relative '../remote-path'
require_relative 'remote-io'
require_relative '../open-flags'

module NonoP
  class RemoteFile
    attr_reader :attachment, :path, :flags, :io
    predicate :ready

    def initialize path, attachment:, fid: nil, flags: nil
      @path = RemotePath.new(path)
      @attachment = attachment
      @flags = NonoP::OpenFlags.new(flags || :RDONLY)
      @io = RemoteIO.new(client, fid || client.next_fid, @path)
      @reqs = NonoP::Client::PendingRequests.new(client).after(&:last)
    end

    def fid; io.fid; end
    
    def client
      attachment.client
    end

    def parent_fid
      attachment.fid
    end

    def open mode: nil, gid: nil, &blk
      @reqs << attachment.walk(@path, nfid: fid) do |pkt|
        NonoP.vputs { "Walked to #{@path} #{@flags} #{@flags & :CREATE} #{@path.size} #{pkt.inspect}" }
        case pkt
        when Rwalk then
          if pkt.nwqid < @path.size
            @reqs << client.clunk(fid) do 
              if @flags & :CREATE
                create(mode: mode, gid: gid, &blk)
              else
                NonoP.maybe_call(blk, WalkError.new(Errno::ENOENT::Errno, @path.parent(pkt.nwqid + 1, from_top: true)))
              end
            end
          else
            client.track_fid(fid) { self.close }
            @reqs << client.request(NonoP::L2000::Topen.
                                   new(fid: fid,
                                       flags: @flags)) do |pkt|
              NonoP.vputs("Post walk: #{self} #{fid} #{ready?.inspect} #{@reqs.size}")
              if ErrorPayload === pkt
                NonoP.maybe_call(blk, OpenError.new(pkt))
              else
                ready!
                NonoP.maybe_call(blk, self)
              end
            end
          end
        when ErrorPayload then NonoP.maybe_call(blk, pkt)
        else raise TypeError.new(pkt)
        end
      end
      self
    end

    def wait
      NonoP.vputs { "File wait: #{ready?.inspect} #{@reqs.size}" }
      @reqs.wait.tap { NonoP.vputs("  Waited for #{@reqs.size} #{_1.inspect}") } if !@reqs.empty?
      # self
    end
    
    def create mode: nil, gid: nil, &blk
      @reqs << attachment.walk(@path.parent, nfid: fid) do |pkt|
        case pkt
        when Rwalk then
          if pkt.nwqid < @path.size - 1
            # todo test creating in directories that do not exist
            NonoP.maybe_call(blk, CreateError.new(pkt, path))
          else
            client.track_fid(fid) { self.close }
            @reqs << client.request(L2000::Tcreate.
                                   new(fid: fid,
                                       name: NString.new(@path.basename),
                                       flags: @flags,
                                       mode: mode || 0644,
                                       gid: gid || 0)) do |pkt|
              case pkt
              when Rcreate
                ready!
                NonoP.maybe_call(blk, self)
              when ErrorPayload then NonoP.maybe_call(blk, CreateError.new(pkt, path))
              else raise TypeError.new(pkt)
              end
            end
          end
        when ErrorPayload then NonoP.maybe_call(blk, WalkError.new(pkt, path))
        else raise TypeError.new(pkt)
        end
      end
    end

    def close &blk
      r = @io.close(&blk)
      unready!
      r
    end

    # todo length limited to msglen
    # todo handling multiple replies for big reads
    def read length, offset: 0, &blk
      @io.read(length, offset:, &blk)
    end

    def write data, offset: 0, length: nil, &blk
      @io.write(data, offset:, length:, &blk)
    end

    def write_one data, offset: 0, &blk
      @io.write_one(data, offset:, &blk)
    end
  end
end
