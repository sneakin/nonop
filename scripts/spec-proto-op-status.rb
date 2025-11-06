#!/usr/bin/env -S sg-rspec-report -f

# todo enumerate results by backend, currently the default driver of client; now needs new columns in reports

require 'nonop'

@grouped = true

Blacklist = [ 'TimeT' ]

# ProtoOps = NonoP::L2000::Decoder::RequestReplies.values.
ProtoOps = [ 'Tlopen' ] +
  [ NonoP, NonoP::L2000 ].collect(&:constants).flatten.collect(&:name).uniq.
  select(&/\AT/).reject { Blacklist.include?(_1) }

examples = examples.group_by do |ex|
  ProtoOps.find do |op|
    ex['full_description'] =~ /#{op}/
  end || 'unknown'
end

ProtoOps.each { |x| examples[x] = [] unless examples.has_key?(x) }

examples
