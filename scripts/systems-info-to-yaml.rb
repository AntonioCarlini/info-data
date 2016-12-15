#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataSystemsInfo.rb"

require "yaml"

sys_type = ARGV.shift()    # This might be 'vax' or 'alpha' etc.
sys_info = ARGV.shift()    # This is the systems .info file
refs_yaml = ARGV.shift()   # This is the references YAML file

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the systems .info file
systems = Systems.create_from_info_file(sys_info, sys_type, refs)

# Output as YAML
puts(systems.to_yaml())

