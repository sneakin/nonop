# todo have each type only handle @data?
# todo much much; only decodes a failed mount

require 'sg/ext'
using SG::Ext

module NineP
  MAX_U64 = 0xFFFFFFFFFFFFFFFF
end

require_relative 'ninep/util'
require_relative 'ninep/decoder'
require_relative 'ninep/client'

