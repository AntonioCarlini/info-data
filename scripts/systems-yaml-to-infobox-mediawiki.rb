#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataTags.rb"

require "yaml"

class Output
  def initialize(build_xml)
    @build_xml = build_xml
  end

  def puts(text="")
    # First swap out the initial ampersands (as other swaps will put *in* ampersands)
    # The order of the other substitutions does not currently matter.
    text = text.gsub(/&/,"&amp;").gsub(%r{\"},"&quot;").gsub(/</,"&lt;").gsub(/>/,"&gt;") if @build_xml
    $stdout.puts(text)
  end

  def puts_xml(text)
    $stdout.puts(text)
  end
end

sys_type = ARGV.shift()    # This might be 'vax' or 'alpha' etc.
sys_yaml = ARGV.shift()    # This is the systems YAML file
tags_yaml = ARGV.shift()   # This is the tags YAML file
refs_yaml = ARGV.shift()   # This is the references YAML file

build_xml = true

# Load the references YAML information
refs = YAML.load_file(refs_yaml)

# Load the systems YAML information
systems = YAML.load_file(sys_yaml)

# Load the supplied tags
tags = DataTags.new(tags_yaml, 'systems', sys_type)

op = Output.new(build_xml)

# This is the time with which the XML page entries will be stamped
page_time = Time.now().strftime("%Y-%m-%dT%H:%M:%SZ")

# The comment will indicate the latest modification time of the source file
source_file_time = File.mtime(sys_yaml)

# systems will be a hash of {system name => properties-hash} 
# properties-hash will be {property => array-of-values}
# array-of-values[0] will be the value, [1] onwards will be references.

op.puts_xml(%q[<mediawiki xml:lang="en">]) if build_xml
systems.keys().each() {
  |id|
  local_refs = {} # [index, ref-hash-from-yaml] }
  next_local_refs_index = 1
  properties = systems[id]
  system_name_array = properties["Sys-name"]
  if system_name_array.nil?()
    $stderr.puts("Cannot find Sys-name for [#{id}] so skipping")
    next
  end

  # Work out a plausible name; default to "UNKNOWN"
  d_name = properties["Desc-name"]
  s_name = properties["Sys-name"]
  name = nil
  name = d_name[0] unless d_name.nil?()
  if name.nil?()
    name = s_name[0] unless s_name.nil?()
    name = "UNKNOWN" if name.nil?() || name.empty?()
  end

  name_prefix = (sys_type =~ /vax/i) ? "DEC " : ""  # prefix VAX pages with DEC to produce "DEC VAX"

  if build_xml
    op.puts_xml(%Q[  <page>])
    op.puts_xml(%Q[    <title>#{name_prefix}#{name} systems</title>])
    op.puts_xml(%Q[    <revision>])
    op.puts_xml(%Q[      <timestamp>#{page_time}</timestamp>])
    op.puts_xml(%Q[      <comment>Created from #{File.basename(sys_yaml)}, last modified at #{source_file_time}</comment>])
    op.puts_xml(%Q[      <contributor><username>antonioc-scripted</username></contributor>])
    op.puts_xml(%Q[      <text>])
  end
  op.puts("== #{name_prefix}#{name} systems ==")
  op.puts()
  op.puts("{{Infobox#{sys_type.upcase()}-Data")
  op.puts("| name = #{name}")
  properties.keys().each() {
    |prop|
    next if prop =~ /sys-class/i # This should be handled in some special way (VAX4000, VAX6000, UNIBUS etc.)
    next if prop =~ /sys-name/i
    next if prop =~ /html-target/i
    next if prop =~ /option-title/i
    next if prop =~ /docs/i
    next if prop =~ /text_block/i
    array_of_values = properties[prop]
    value = array_of_values.shift()
    ref_index = nil   # No reference present, or invalid reference present
    ref_text = ""
    array_of_values.each() {
      |ref_key|
      reference = local_refs[ref_key]
      if reference.nil?()
        local_refs[ref_key] = [ next_local_refs_index, refs[ref_key] ]
        ref_index = next_local_refs_index
        next_local_refs_index += 1
      else
        ref_index = reference[0]
      end
      ref_text << "[[#ref_#{ref_index}|[#{ref_index}]]]"
    }
    ref_text = " " + ref_text unless ref_text.empty?()
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
        ref_text = ""
        reference = local_refs[ref_key]
        if reference.nil?()
          local_refs[ref_key] = [ next_local_refs_index, refs[ref_key] ]
          ref_index = next_local_refs_index
          next_local_refs_index += 1
        else
          ref_index = reference[0]
        end
        ref_text << "[[#ref_#{ref_index}|[#{ref_index}]]]"
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

  unless local_refs.empty?()
    op.puts("== References ==")
    op.puts()
    ref_text_array = []
    local_refs.each() {
      |key, value|
      index = value[0]
      properties = value[1]
      entry = properties['title']
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
