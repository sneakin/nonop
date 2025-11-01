require 'ffi/libc/statfs'

module NonoP
  module Ext
    module StatFS
    end
  end
end

module NonoP::Ext::StatFS
  refine File.singleton_class do
    def statfs path
      out = FFI::LibC::StatFS.new
      case FFI::LibC.statfs(path, out)
      when 0 then return out
      else raise SystemCallError.new(-r)
      end
    end
  end

  refine Pathname do
    def statfs
      File.statfs(self.to_s)
    end
  end
end
