#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataTerminalsInfo.rb"
require_relative "DataTags.rb"

require "yaml"

terminal_type = ARGV.shift()    # This might be 'decvt'
terminal_info = ARGV.shift()    # This is the terminals .info file
tags_yaml = ARGV.shift()        # This is the tags YAML file
refs_yaml = ARGV.shift()        # This is the references YAML file
pubs_yaml = ARGV.shift()        # This is the publications YAML file

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the publications YAML information
pubs = YAML.load_file(pubs_yaml)

tags = DataTags.new(tags_yaml, 'systems', terminal_type).tags()

# Load the systems .info file
terminals = EntriesCollection.create_from_info_file(terminal_info, terminal_type, tags, refs, pubs)

# Output as YAML
puts(terminals.to_yaml())

