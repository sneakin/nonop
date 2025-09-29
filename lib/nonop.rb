# todo have each type only handle @data?
# todo much much; only decodes a failed mount

require 'sg/ext'
using SG::Ext

module NonoP
  MAX_U64 = 0xFFFFFFFFFFFFFFFF
end

require_relative 'nonop/util'
require_relative 'nonop/decoder'
require_relative 'nonop/client'

