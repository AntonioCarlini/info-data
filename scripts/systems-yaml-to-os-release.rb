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

require_relative "ClassTrackLocalReferences.rb"
require_relative "DataTags.rb"

require "yaml"

# Sort out references
# Add any other page data such as Category


# OsVersionsTracker
#
# This class tracks start and end OS support versions for a given system.
# Currently only OpenVMS is supported, but that may change in the future.
class OsSupport
  attr_reader  :support_start
  attr_reader  :support_end

  def initialize(start_version, end_version)
    @support_start = start_version
    @support_end = end_version
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
  # Currently do this for VMS only but eventually consider support for other OSes
  # Currently this is VAX-only.

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



    vms_support_name_array = properties["OS-support-VMS"]
    vms_support_early_name_array = properties["OS-support-VMS-early"]
    vms_support_end_name_array = properties["OS-support-VMS-end"]

    vms_start = ""
    unless vms_support_early_name_array.nil?()
      value = vms_support_early_name_array.shift()
      ref_text = local_refs.build_local_refs(vms_support_early_name_array, refs)
      vms_start = "#{value}#{ref_text}"
    end
    unless vms_support_name_array.nil?()
      value = vms_support_name_array.shift()
      ref_text = local_refs.build_local_refs(vms_support_name_array, refs)
      vms_start += ", " unless vms_start.empty?()
      vms_start += "#{value}#{ref_text}"
    end
    vms_end = ""
    unless vms_support_end_name_array.nil?()
      value = vms_support_end_name_array.shift()
      ref_text = local_refs.build_local_refs(vms_support_end_name_array, refs)
      vms_end = "#{value}#{ref_text}"
    end
    results[name] = OsSupport.new(vms_start, vms_end)
  }

  # Run through the systems in alphabetic order and display the results.
  # The output is a valid mediawiki page.
  column_width = 20
  puts(%Q[{| class="wikitable sortable"])
  puts(%Q[! System])
  puts(%Q[! colspan="2" | VMS Support])
  puts(%Q[|-])
  puts(%Q[!])
  puts(%Q[! style="width: #{column_width}ch" | Start])
  puts(%Q[! style="width: #{column_width}ch" | End])

  results.keys().sort().each() {
    |name|
    puts("|-")
    puts("| #{name} || #{results[name].support_start()} || #{results[name].support_end()}")
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
  puts("[[Category:OpenVMS]]")
end

main()

