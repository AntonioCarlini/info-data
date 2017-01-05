#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataTags.rb"

require "yaml"

sys_type = ARGV.shift()    # This might be 'vax' or 'alpha' etc.
tags_yaml = ARGV.shift()   # This is the tags YAML file

# Load the supplied tags
tags = DataTags.new(tags_yaml, 'systems', sys_type)

# Currently a tag looks like this:
#- Announcement:
#  - Announcement date
#  - all
#  - summary
#  - required
#
# Turn this into an InfoBox#{system.upcase()}-Data.
# The section in <noinclude></noinclude> should outline the entries.
# The section in <includeonly></noincludeonly> should implement the entries.

# The system designation (vax, alpha, pdp11) needs to be turned into pretty text.
sys_desc = {}
sys_desc["alpha"] = "Alpha"
sys_desc["mips"] = "MIPS"
sys_desc["pc"] = "DEC PC"
sys_desc["pdp11"] = "PDP-11"
sys_desc["vax"] = "VAX"

# The tags should be in an array of the appropriate order. Gather into sections as required.
# An entry with no sction will be ignored. Any unknown section is to be considered an error.

sections_text = []
sections_text << "summary"
sections_text << "cpu_details"
sections_text << "memory"
sections_text << "io"
sections_text << "performance"
sections_text << "dimensions"
sections_text << "power"
sections_text << "option"

sections = {}
sections_text.each() { |text| sections[text] = [] }

# Process each tag. Track the longest tag name.
longest_tag_name = 0
tags.each_in_order() {
  |tag|
  category = tag.category()
  next if category.nil?() || category.empty?()
  array = sections[category]
  raise("Found bad category [#{category}] in tag #{tag.name()} = #{tag.inspect()}") if array.nil?()
  array << tag
  longest_tag_name = tag.name().length() if tag.name().length() > longest_tag_name
}

# Make an effort to format things nicely even if long tag names creep in under maintenance.
longest_tag_name = 20 if longest_tag_name < 20

# Tags are now all present so write out the required text.
#
# Begin with the text that the user should see when looking at the template.
puts("<noinclude>")
puts("This template is for any #{sys_desc[sys_type.downcase()]} computer system.")
puts()
puts("<pre>")
# Force in a tag of type 'name' to act as sys-name (or maybe desc-name?)
puts("%-#{longest_tag_name + 1}s = %s" % ["name", "the name of the system"])
# Write out the tags and the explanatory information
sections_text.each() {
  |text|
  next if text =~ /dimensions|power|option/    # Ignore dimensions, power and options
  next if sections[text].size() <= 0           # Ignore any section that is empty
  sections[text].each() {
    |tag|
    puts("%-#{longest_tag_name + 1}s = %s" % [tag.name(), tag.explanatory_text()])
  }
}
puts("</pre>")
puts("</noinclude>")

# Now write out the transcluded text
puts(%q^<includeonly>^)
puts(%q^{| class="infobox bordered" style="width: 40em; text-align: left; font-size: 90%" align="right"^)
puts(%q^|-^)
puts(%q^| colspan="2" style="text-align:center; font-size: large;" | '''{{{name}}}'''^)

## TODO: Here consider whether an image + caption should be supported

# Handle each tag and its supplied value
sections_text.each() {
  |text|
  next if text =~ /dimensions|power|option/    # Ignore dimensions, power and options
  next if sections[text].size() <= 0           # Ignore any section that is empty
  # Display the section heading
  # The template will only display the section heading if at least one element is present
  puts(%Q^|-^)
  cond_names = ""
  sections[text].each() {
    |tag|
    cond_names += " {{{#{tag.name()}|}}}"
  }
  puts()
  puts(%Q^{{\#if: #{cond_names} |^)

  # Make the section heading text prettier
  section_heading = text.gsub(/_/,' ').split().map(&:capitalize).join(' ')
  section_heading = section_heading.gsub(/cpu/i,'CPU').gsub(/^io$/i,"I/O")
  puts(%Q^! colspan="2" style="text-align:center;" {{!}} #{section_heading} }}^)
  # Display each section
  sections[text].each() {
    |tag|
    puts(%Q^\|-^)
    puts()
    puts(%Q^{{\#if: {{{#{tag.name()}|}}} |^)
    puts(%Q^! #{tag.display_text()}:^)
    puts(%Q^    {{!}} {{{#{tag.name()}}}} }}^)
  }
}

## TODO: here consider possible footnotes
puts(%q^|}^)

## TODO: here consider possible categories
##puts(%q^[[Category:Historical Computer Information]] [[Category:VAX Information]]^)

puts(%q^</includeonly>^)
