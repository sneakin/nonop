require 'sg/ext'
using SG::Ext

require_relative '../../spec-helper'

SPEC_DRIVER = ENV.fetch('DRIVER', 'client')

Pathname.new(__FILE__).parent.
  glob("../#{SPEC_DRIVER}/*.rb").each { require_relative(_1) }
