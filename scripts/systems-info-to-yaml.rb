#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataSystemsInfo.rb"

require "yaml"

sys_type = ARGV.shift()
sys_info = ARGV.shift()

# Load the refs.info
systems = Systems.create_from_info_file(sys_info, sys_type)

# Output as YAML
puts(systems.to_yaml())

