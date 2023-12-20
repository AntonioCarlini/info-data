#!/usr/bin/env ruby

#+
# This script reads a YAML file of systems data and produces a mediawiki page that lists
# supported OS ranges for each system.
#
# Currently only OpenVMS releases are listed.
#
# Inputs:
#
# sys_type:  Specifies the hardware type, 'vax' or 'alpha' etc.
# sys_yaml:  Filepath of the system YAML file
# refs_yaml: Filepath of the references YAML file
#
# Outputs:
#
# The output is written to stdout as a valid mediawiki page
#
#-

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "ClassOsSupport.rb"
require_relative "ClassItemWithReferenceKeys.rb"
require_relative "ClassTrackLocalReferences.rb"
require_relative "DataTags.rb"

require "yaml"

#+
# This class handles any data that is to be stored and then retrieved for each system.
# Using this rather than an array makes the code easier to understand.
#
class DataTracker
  attr_accessor :announcement
  attr_reader   :os_support

  def initialize(local_refs, global_refs)
    @announcement = nil
    @os_support = []
    @local_refs = local_refs
    @global_refs = global_refs
  end

  def announcement=(announcement_property)
    unless announcement_property.nil?()
      item = ItemWithReferenceKeys.new(announcement_property)
      @announcement = item.value_with_refs(@local_refs, @global_refs)
    end
  end

  # Stores an OsSupport object for each OS that is handled.
  # The exact number of these depends on the hardware (as each has differing sets of reported OSes).
  # Each of os_support_early, os_support_start, os_support_end is a property value.
  def os_support_add(os_support_early, os_support_start, os_support_end)
      early_support = nil
      early_support = ItemWithReferenceKeys.new(os_support_early) unless os_support_early.nil?()

      start_support = nil
      start_support = ItemWithReferenceKeys.new(os_support_start) unless os_support_start.nil?()
    
      end_support = nil
      end_support = ItemWithReferenceKeys.new(os_support_end) unless os_support_end.nil?()

      @os_support << OsSupport.new(early_support, start_support, end_support).build_text(@local_refs, @global_refs)
  end
end

def main
  sys_type = ARGV.shift()    # This might be 'vax' or 'alpha' etc.
  sys_yaml = ARGV.shift()    # This is the systems YAML file
  refs_yaml = ARGV.shift()   # This is the references YAML file

  # Load the references YAML information
  refs = YAML.load_file(refs_yaml)

  # Load the systems YAML information
  systems = YAML.load_file(sys_yaml)

  local_refs = TrackLocalReferences.new()

  # systems will be a hash of {system name => properties-hash} 
  # properties-hash will be {property => array-of-values}
  # array-of-values[0] will be the value, [1] onwards will be references.

  # For each system, note the system title, the starting OS-support and the end OS-support.
  # Do this for each OS supported by the platform, in the order they are specified.
  platforms = {
    "vax" => ["VMS", "ULTRIX", "ELN"],
    "alpha" => ["VMS", "DU", "NT"],
    "decmips" => ["ULTRIX", "DU"],
    "pdp11" => ["RSX-11M"],
    "pc" => ["NT"]
  }
  os_display_name = {"VMS" => "VMS", "ULTRIX" => "ULTRIX", "ELN" => "VAXELN", "DU" => "Digital UNIX", "NT" => "Windows NT"}

  # "DU" covers OSF/1, Digital UNIX and Tru64, as the OS changed its name over its lifetime.
  # DEC MIPS systems were only ever supported by DEC OSF/1 from V1.0 until all MIPS support was dropped in V1.2.
  # So if the system is MIPS, the only sensible name is "DEC OSF/1".
  os_display_name["DU"] = "DEC OSF/1" if sys_type == "decmips"
  
  platform_set = platforms[sys_type]
  raise("Urecognised platform: [#{sys_type}]") if platform_set.nil?()
  
  results = {}
  systems.keys().each() {
    |id|
    properties = systems[id]
    d_name = properties["Desc-name"]
    s_name = properties["Sys-name"]
    name = nil
    name = d_name[0] unless d_name.nil?()
    if name.nil?()
      name = s_name[0] unless s_name.nil?()
      name = "UNKNOWN" if name.nil?() || name.empty?()
    end

    data = DataTracker.new(local_refs, refs)
    data.announcement = properties["Announcement"]
    # Start with the announcement value
    results[name] = [ data.announcement() ]

    # Loop through each specified OS, adding the support data to the results array.
    # Note that "OS-support-???-early/end" only exist for VMS but as they will return nil for
    # other OSes, that will appear to be the same as that particular property not being specified
    # for this hardware. That achieves the required result and also allows for the possibility
    # that some other OSes  may acquire these properties as more information becomes available
    # in the future.
    platform_set.each() {
      |os|
      data.os_support_add(properties["OS-support-#{os}-early"], properties["OS-support-#{os}"], properties["OS-support-#{os}-end"])
    }
    results[name] = data
  }

  # Run through the systems in alphabetic order and display the results.
  # The output is a valid mediawiki page.
  column_width = 20
  puts(%Q[{| class="wikitable sortable"])
  puts(%Q[! System])
  puts(%Q[! Announcement])
  platform_set.each() { |os| puts(%Q[! colspan="2" | #{os_display_name[os]} Support]) }
  puts(%Q[|-])
  puts(%Q[!])
  puts(%Q[!])
  platform_set.each() {
    |os|
    puts(%Q[! style="width: #{column_width}ch" | Start])
    puts(%Q[! style="width: #{column_width}ch" | End])
  }
  results.keys().sort().each() {
    |name|
    puts("|-")
    print("| #{name}")
    print("|| #{results[name].announcement()}")
    results[name].os_support().each() {
      |support|
      print(" || #{support.os_begin_support()} || #{support.os_finish_support()}")
    }
    puts("")
  }
  puts(%Q[|}])
  puts()

  unless local_refs.empty?()
    puts("== References ==")
    puts()
    ref_text_array = []
    local_refs.each_ref() {
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
    ref_text_array.each() { |line| puts(line) }
  end

  puts()
  puts("[[Category:Classic Computing]]")
  puts("[[Category:OpenVMS]]") if platform_set.include?("VMS")
end

main()

