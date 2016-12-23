#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataTags.rb"

require "yaml"

sys_type = ARGV.shift()    # This might be 'vax' or 'alpha' etc.
sys_yaml = ARGV.shift()    # This is the systems YAML file
tags_yaml = ARGV.shift()   # This is the tags YAML file
refs_yaml = ARGV.shift()   # This is the references YAML file

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the systems YAML information
systems = YAML.load_file(sys_yaml)

# Load the supplied tags
tags = DataTags.new(tags_yaml, 'systems', sys_type)

# systems will be a hash of {system name => properties-hash} 
# properties-hash will be {property => array-of-values}
# array-of-values[0] will be the value, [1] onwards will be references.

systems.keys().each() {
  |id|
  local_refs = {} # { ref-id => [index, ref-hash-from-yaml] }
  next_local_refs_index = 1
  properties = systems[id]
  system_name_array = properties["Sys-name"]
  if system_name_array.nil?()
    $stderr.puts("Cannot find Sys-name for [#{id}] so skipping")
    next
  end
  system_name = system_name_array[0]
  puts("== Specifications for #{system_name} ==")
  puts()
  puts("{{Infobox#{sys_type.upcase()}-Data")
  # Work out a plausible name; default to "UNKNOWN"
  d_name = properties["Desc-name"]
  s_name = properties["Sys-name"]
  name = nil
  name = d_name[0] unless d_name.nil?()
  if name.nil?()
    name = s_name[0] unless s_name.nil?()
    name = "UNKNOWN" if name.nil?() || name.empty?()
  end
  puts("| name = #{name}")
  properties.keys().each() {
    |prop|
    next if prop =~ /sys-class/i # This should be handled in some special way (VAX4000, VAX6000, UNIBUS etc.)
    next if prop =~ /sys-name/i
    next if prop =~ /html-target/i
    next if prop =~ /option-title/i
    array_of_values = properties[prop]
    value = array_of_values[0]
    ref_index = nil   # No reference present, or invalid reference present
    if array_of_values.size() > 1
      r = array_of_values[1]  # a reference ID
      if local_refs[r].nil?()
        local_refs[r] = [ next_local_refs_index, refs[r] ]
        next_local_refs_index += 1
      else
        ref_index = local_refs[r][0]
      end
    end
    if ref_index.nil?()
      ref_text = ""
    else
      ref_text = " [[#ref_#{ref_index}|[#{ref_index}]]]"
    end
    puts("| #{tags[prop].name()} = #{value}#{ref_text}")
  }
  puts("}}")
  puts()
  unless local_refs.empty?()
    puts("== References ==")
    puts()
    ref_text_array = []
    local_refs.each() {
      |key, value|
      index = value[0]
      properties = value[1]
      ref_text_array << %Q% <div id="ref_#{index}">[#{index}] #{properties['title']}. #{properties['part-no']}</div>%
    }
    ref_text_array.sort().each() { |line| puts(line) }
  end
}
