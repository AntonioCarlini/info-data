#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataStorageInfo.rb"
require_relative "DataTags.rb"

require "yaml"

storage_type = ARGV.shift()    # This might be 'dssi' or 'sdi' or 'scsi' etc.
storage_info = ARGV.shift()    # This is the storage .info file
tags_yaml = ARGV.shift()       # This is the tags YAML file
refs_yaml = ARGV.shift()       # This is the references YAML file
pubs_yaml = ARGV.shift()       # This is the publications YAML file

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the publications YAML information
pubs = YAML.load_file(pubs_yaml)

tags = DataTags.new(tags_yaml, 'storage', storage_type).tags()

# Load the systems .info file
storage = StorageDevices.create_from_info_file(storage_info, storage_type, tags, refs, pubs)

# Output as YAML
puts(storage.to_yaml())

