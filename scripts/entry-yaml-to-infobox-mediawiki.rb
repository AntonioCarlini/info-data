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

# A class to hold data required for each option
class OptionInfo

  attr_reader  :desc_name
  attr_reader  :page_name
  attr_reader  :sys_name

  def initialize(page_name_prefix, sys_name, desc_name)
    @sys_name = sys_name
    @desc_name = desc_name
    @page_name, _ = build_page_name(page_name_prefix, sys_name, desc_name)
  end

  # Return a description following the algorithm of the original code.
  # As "Desc-name" should always be present, thisshould always be @desc_name, but just in case ...
  def description()
    desc = @desc_name
    desc = @sys_name if desc_name.nil?() || desc_name.empty?()
    return desc
  end

end

# Keep the logic that builds a page name all in one place.
def build_page_name(prefix, sys_name, desc_name)
  name = nil
  name = desc_name unless desc_name.nil?()
  if name.nil?()
    name = sys_name unless sys_name.nil?()
    name = "UNKNOWN" if name.nil?() || name.empty?()
  end
  return prefix + name, name
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

entry_class = ARGV.shift()     # This is the entry class : 'systems' or 'storage' etc.
entry_type = ARGV.shift()      # This might be 'st506' or 'dssi' etc.
entry_yaml = ARGV.shift()      # This is the entry YAML file
tags_yaml = ARGV.shift()       # This is the tags YAML file
refs_yaml = ARGV.shift()       # This is the references YAML file
options_yaml = ARGV.shift()    # This is the YAML holding options

page_name_prefix = "DEC "      # prefix all pages with DEC to produce "DEC device"

options_data = {}
opt_entries = YAML.load_file(options_yaml)
opt_entries.keys().each() {
    |id|
    sys_name = opt_entries[id]['Sys-name']
    sys_name = sys_name[0] unless sys_name.nil?()
    desc_name = opt_entries[id]['Desc-name']
    desc_name = desc_name[0] unless desc_name.nil?()

    # Record the original data before further manipulation
    options_info = OptionInfo.new(page_name_prefix, sys_name, desc_name)
    
    desc_name = sys_name if desc_name.nil?() || desc_name.empty?()

    # The final system name must not be empty
    raise("Options YAML: ID [#id] has empty system name.") if sys_name.nil?() || sys_name.empty?()
    # The final description must not be empty
    raise("Options YAML: ID [#id] has empty desciption.") if desc_name.nil?() || desc_name.empty?()

    # Use id as an index but ensure that it is unique
    raise("Options YAML: entry for ID [#{id}] has already been seen.") if options_data.key?(id)
    options_data[id] = options_info

    # Only use sys_name as an index if it differs from id
    if sys_name != id
      raise("Options YAML: entry for ID [#{sys_name}] has already been seen.") if options_data.key?(sys_name)
      options_data[id] = options_info
    end
}

build_xml = true

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the entry YAML information
entry_data = YAML.load_file(entry_yaml)

# Load the supplied tags
tags = DataTags.new(tags_yaml, entry_class, entry_type)

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
  page_name, name = build_page_name(page_name_prefix, s_name[0], d_name[0])

  if build_xml
    op.puts_xml(%Q[  <page>])
    op.puts_xml(%Q[    <title>#{page_name}</title>])
    op.puts_xml(%Q[    <revision>])
    op.puts_xml(%Q[      <timestamp>#{page_time}</timestamp>])
    op.puts_xml(%Q[      <comment>Created from #{File.basename(entry_yaml)}, last modified at #{source_file_time}</comment>])
    op.puts_xml(%Q[      <contributor><username>antonioc-scripted</username></contributor>])
    op.puts_xml(%Q[      <text>])
  end

  # OS-support-VMS, OS-support-VMS-early and OS-support-end need special handling.


  op.puts("== #{page_name} ==")
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

  # Write out any options that have been specified for this  entry.
  # Currently the code allows multiple Options blocks in a single .info file entry, which explains the extra level of arrays involved.
  # However, all of these are collapsed into a single table in the final wiki page.
  #
  # TODO
  # Note that, where an options_data[] entry exists for the specified key, it should be possible to generate an internal wiki
  # link to the appropriate page (although it has to be assumed that such a page will exist as there is no way of knowing
  # whether such a page - even if this repo generates it - will have been imported into the wiki).
  options = properties["options_block"]
  unless options.nil?()
    op.puts("== Hardware Options ==")
    op.puts()
    options.each() {
      |opt|
      # Each array entry represents one options block.
      # Each options block is an array of entries, each of which is either
      #   ["option_title", title]
      # or
      #   ["option_text, ["CLASS:KEY", "DESCRIPTION", REFERENCES ...]
      #
      # REFERENCES is a list of references but it is optional and may be completely absent
      # CLASS is optional, in which case there will be no ':'
      op.puts('{| class="wikitable"')
      opt.each() {
        |entry|
        case entry[0]
        when "option_text"
          ref_text = ""
          text_array = entry[1]
          # Build reference text, if any refs are present
          ref_text = lref.build_local_refs(text_array[2..], refs) if text_array.size() >= 2

          class_key = text_array[0].strip()
          desc = text_array[1].strip()
          opt_class = ""
          opt_key = ""
          if class_key =~ /^(.*?):(.*)$/
            opt_class = $1.strip()
            opt_key = $2.strip()
          else
            opt_key = class_key.strip()
          end
          value = options_data[opt_key]
          op.puts("|-")
          if value.nil?()
            op.puts("| #{opt_key} #{ref_text} || #{desc}")
          else
            op.puts("| [[#{value.page_name()} | #{opt_key}]] #{ref_text} || #{value.description()}")
          end
        when "option_title"
          op.puts("|-")
          op.puts("! colspan=\"2\" | #{entry[1]}")
        end
      }
      op.puts('|}')
    }
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
