#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "ClassTrackLocalReferences.rb"
require_relative "DataTags.rb"

require "yaml"

class Output
  def initialize(build_xml)
    @build_xml = build_xml
  end

  # Write out text after transforming it to make it valid XML.
  def puts(text="")
    # First swap out the initial ampersands (as other swaps will put *in* ampersands)
    # The order of the other substitutions does not currently matter.
    text = text.gsub(/&/,"&amp;").gsub(%r{\"},"&quot;").gsub(/</,"&lt;").gsub(/>/,"&gt;") if @build_xml
    $stdout.puts(text)
  end

  # Write out text that is already valid XML.
  # No transformation is performed.
  def puts_xml(text)
    $stdout.puts(text)
  end
end

# A generic class to hold an item and the relevant references.
class ItemWithReferenceKeys

  attr_reader  :item
  attr_reader  :refs

  def initialize(item, refs)
    @item = item      # Whatever the item is
    @refs = refs      # Should be an array of keys
  end
  
end

# Handle OS-support-VMS and related properties.
# OS-support-VMS, OS-support-VMS-early and OS-support-end need special handling.
# If OS-support-VMS-early exists, prepend it with a trailing comma and space to OS-support.
# If OS-support-VMS-end exists, append the text " to " and then OS-support-VMS-end to OS-support-VMS
# In either case, if OS-support-VMS does not exist, it is an error and processing should stop
#
# To handle the references:
# - for each of the component parts, produce the relevant value text and add the references
# - build up the final string (which now includes all the individual references)
# - replace the value of OS-support-VMS with the final text (which has references embedded) and no further references
# When OS-support-VMS is finally output, it will be written as text with the appropriate references.
def process_os_support_vms(properties, lref, refs)
  # Begin by building the base value of OS-support-VMS and its references
  base_value = ""
  if properties.key?("OS-support-VMS")
    array_of_values = properties["OS-support-VMS"]
    base_value = array_of_values.shift()
    base_ref_text = lref.build_local_refs(array_of_values, refs)
    base_value = "#{base_value}#{base_ref_text}"
  end

  # For each of the supporting properties that is present, build the text and references and add to the base value above
  if properties.key?("OS-support-VMS-early")
    raise("OS-support-VMS-early without OS-support-VMS for device #{name}") if not properties.key?("OS-support-VMS")
    array_of_values = properties["OS-support-VMS-early"]
    value = array_of_values.shift()
    ref_text = lref.build_local_refs(array_of_values, refs)
    base_value = "#{value}#{ref_text}, " + base_value
  end
  if properties.key?("OS-support-VMS-end")
    raise("OS-support-VMS-end without OS-support-VMS for device #{name}") if not properties.key?("OS-support-VMS")
    array_of_values = properties["OS-support-VMS-end"]
    value = array_of_values.shift()
    ref_text = lref.build_local_refs(array_of_values, refs)
    base_value = "#{base_value} to " + "#{value}#{ref_text}"
  end

  # Finally, replace the OS-support-VMS property with the fully referenced text that was built
  properties["OS-support-VMS"] = [ base_value ]
end

entry_type = ARGV.shift()      # This might be 'st506' or 'dssi' etc.
entry_yaml = ARGV.shift()      # This is the entry YAML file
tags_yaml = ARGV.shift()       # This is the tags YAML file
refs_yaml = ARGV.shift()       # This is the references YAML file

build_xml = true

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the entry YAML information
entry_data = YAML.load_file(entry_yaml)

# Load the supplied tags
tags = DataTags.new(tags_yaml, 'storage', entry_type)

op = Output.new(build_xml)

# This is the time with which the XML page entries will be stamped
page_time = Time.now().strftime("%Y-%m-%dT%H:%M:%SZ")

# The comment will indicate the latest modification time of the source file
source_file_time = File.mtime(entry_yaml)

# entry_data will be a hash of {device name => properties-hash} 
# properties-hash will be {property => array-of-values}
# array-of-values[0] will be the value, [1] onwards will be references.

op.puts_xml(%q[<mediawiki xml:lang="en">]) if build_xml
entry_data.keys().each() {
  |id|
  properties = entry_data[id]
  device_name_array = properties["Sys-name"]
  if device_name_array.nil?()
    $stderr.puts("Cannot find Sys-name for [#{id}] so skipping")
    next
  end

  lref = TrackLocalReferences.new()

  # Work out a plausible name; default to "UNKNOWN"
  d_name = properties["Desc-name"]
  s_name = properties["Sys-name"]
  name = nil
  name = d_name[0] unless d_name.nil?()
  if name.nil?()
    name = s_name[0] unless s_name.nil?()
    name = "UNKNOWN" if name.nil?() || name.empty?()
  end

  name_prefix = "DEC "  # prefix all pages with DEC to produce "DEC device"

  if build_xml
    op.puts_xml(%Q[  <page>])
    op.puts_xml(%Q[    <title>#{name_prefix}#{name}</title>])
    op.puts_xml(%Q[    <revision>])
    op.puts_xml(%Q[      <timestamp>#{page_time}</timestamp>])
    op.puts_xml(%Q[      <comment>Created from #{File.basename(entry_yaml)}, last modified at #{source_file_time}</comment>])
    op.puts_xml(%Q[      <contributor><username>antonioc-scripted</username></contributor>])
    op.puts_xml(%Q[      <text>])
  end

  # OS-support-VMS, OS-support-VMS-early and OS-support-end need special handling.
  

  op.puts("== #{name_prefix}#{name} ==")
  op.puts()
  op.puts("{{Infobox#{entry_type.upcase()}-Data")
  op.puts("| name = #{name}")
  properties.keys().each() {
    |prop|
    next if prop =~ /sys-class/i # This should be handled in some special way (VAX4000, VAX6000, UNIBUS etc.)
    next if prop =~ /sys-name/i
    next if prop =~ /html-target/i
    next if prop =~ /option-title/i
    next if prop =~ /docs/i
    next if prop =~ /text_block/i
    next if prop =~ /power_block/i
    next if prop =~ /dimensions_block/i
    next if prop =~ /options_block/i
    next if prop =~ /local_references/i
    next if prop =~ /OS-support-VMS-early/i  # folded into OS-support-VMS
    next if prop =~ /OS-support-VMS-end/i    # folded into OS-support-VMS
    process_os_support_vms(properties, lref, refs) if prop =~ /OS-support-VMS/i    # pre-process OS-support-VMS, then process as any other property
    
    array_of_values = properties[prop]
    value = array_of_values.shift()
    ref_text = lref.build_local_refs(array_of_values, refs)
    op.puts("DEBUG prop=[#{prop}]")
    op.puts("| #{tags[prop].name()} = #{value}#{ref_text}")
  }
  op.puts("}}")
  op.puts()

  # Display a text block if one is present.
  unless properties["text_block"].nil?()
    properties["text_block"].each() {
      |line|
      line.gsub!(/ \*\*tref \{ ([^}]+) \}/ix) {
        |m|
        ref_key = $1
        ref_text = lref.build_single_ref(ref_key, refs[ref_key])
        "#{ref_text}"
     }
      op.puts("#{line}") 
    }
    op.puts()
  end

  unless properties["docs"].nil?()
    op.puts("== Related Documents ==")
    op.puts()
    properties["docs"].each() { |title| op.puts("<div>#{title}</div>") }
    op.puts()
  end

  unless lref.empty?()
    op.puts("== References ==")
    op.puts()
    ref_text_array = []
    lref.each_ref() {
      |key, value|
      index = value[0]
      properties = value[1]
      entry = ""
      entry += "[#{properties['url']} " unless properties['url'].nil?()
      entry += properties['title']
      entry += "]" unless properties['url'].nil?()
      entry += ". " + properties['part-no'] unless properties['part-no'].nil?()
      entry += ". " + properties['author'] unless properties['author'].nil?()
      entry += ". " + properties['date'] unless properties['date'].nil?()
      entry += ". ISBN " + properties['isbn'] unless properties['isbn'].nil?()
      ref_text_array << %Q% <div id="ref_#{index}">[#{index}] #{entry}</div>%
    }
    ref_text_array.sort().each() { |line| op.puts(line) }
  end
  if build_xml
    op.puts_xml(%q[       </text>])
    op.puts_xml(%q[    </revision>])
    op.puts_xml(%q[  </page>])
  end
}

op.puts_xml(%q[</mediawiki>]) if build_xml
