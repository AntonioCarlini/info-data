#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataEntriesInfo.rb"
require_relative "DataTags.rb"

require "yaml"

entry_type = ARGV.shift()       # This might be 'decvt' or 'vax'
entry_info = ARGV.shift()       # This is the source .info file
tags_yaml = ARGV.shift()        # This is the tags YAML file
refs_yaml = ARGV.shift()        # This is the references YAML file
pubs_yaml = ARGV.shift()        # This is the publications YAML file

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the publications YAML information
pubs = YAML.load_file(pubs_yaml)

tags = DataTags.new(tags_yaml, 'systems', entry_type)

# Load the .info file
collection = EntriesCollection.create_from_info_file(entry_info, entry_type, tags, refs, pubs)

collection.each() {
  |id, entry|
  values_with_no_ref = 0
  reported_offline_refs = {}
  
  # For each possible tag, if it is present, represent it in the output.
  entry.tags.tag_array().each() {
    |value|
    next if value.name() == "Sys-class"
    next if value.name() == "Sys-name"
    next if value.name() == "Desc-name"
    instance_variable_name = EntriesCollection.tag_to_instance_variable_name(value.name())
    if entry.instance_variable_defined?(instance_variable_name)
      # Use tag name (i.e. value.name()) for the "name" and represent the value as an array with the first element as the actual value
      # and any further elements representing references.
      stuff = entry.instance_variable_get(instance_variable_name).as_array()
      used_refs = stuff.drop(1) # remove the value to leave just the references
      if used_refs.empty?()
        ## TODO puts("Value cited without a reference for #{value.name()}")
        values_with_no_ref += 1
      else
        used_refs.each() {
          |r|
          if not refs.key?(r)
            puts("MISSING ref [#{r}] in entry #{id} not found in #{refs_yaml}")
          elsif refs[r]["url"].nil?() or refs[r]["url"].empty?()
            if not reported_offline_refs.key?(r)
              puts("OFFLINE ref [#{r}] in entry #{id}")
              reported_offline_refs[r] = "Reported"
            end
          end
        }
      end
    end
  }

  if values_with_no_ref > 0
    puts("For entry #{id} found #{values_with_no_ref} values cited without a reference")
  end
}
