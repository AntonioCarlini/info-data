#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataPubTxt.rb"

require "yaml"

info = ARGV.shift()

# Load the refs.info
pubs = Publications.create_from_info_file(info)

# Output as YAML
puts(pubs.to_yaml())
