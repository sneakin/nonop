require_relative '../../spec-helper'

Pathname.new(__FILE__).parent.
  glob('../requests/*.rb').each { require_relative(_1) }
