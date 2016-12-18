#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataTags.rb"

require "yaml"

def convert_property_name_to_text(property)
  name_to_text = {
    "sys_class" => "System class",
    "announcement" => "Announcement date",
    "frs_date" => "FRS date",
    "last_order" => "Last order date",
    "last_ship" => "Last ship date",
    "eosl" => "End of service life",
    "codename" => "Codename",
    "cpu" => "CPU Details",
    "cpu_name_vms" => "CPU name (VMS)",
    "cpu_name_console" => "CPU name (console)",
    "cpu_module" => "CPU module",
    "module" => "Module",
    "num_proc" => "Number of processors",
    "cpu_chip" => "CPU chip",
    "fpu_chip" => "FPU chip",
    "cpu_technology" => "CPU technology",
    "cpu_cycle" => "CPU cycle time",
    "cpu_clock" => "CPU clock",
    "vups" => "VUPs",
    "tpc_a" => "TPC-A benchmark",
    "specmarks" => "SPECmarks",
    "specint89" => "SPECint89",
    "specfp89" => "SPECfp89",
    "vms_cpu" => "VMS DCL CPU value",
    "vms_xcpu" => "VMS DCL XCPU value",
    "sid" => "SID",
    "xsid" => "XSID",
    "os_support_vms" => "OS support (VMS)",
    "os_support_mdm" => "OS support (MDM)",
    "os_support_eln" => "OS support (ELN)",
    "os_support_ultrix" => "OS support (ULTRIX)",
    "on_board_memory" => "On-board memory",
    "cpu_names" => "CPU names",
    "vector_processor" => "Vector processor",
    "instruction_buffer_bytes" => "Instruction buffer",
    "instruction_buffer" => "Instruction buffer",
    "translation_buffer_entries" => "Translation buffer",
    "translation_buffer" => "Translation buffer",
    "control_store" => "Control store",
    "gate_delay" => "Gate delay",
    "wcs" => "WCS",
    "uwcs" => "UWCS",
    "cache" => "Cache",
    "primary_cache" => "Primary cache",
    "secondary_cache" => "Secondary cache",
    "backup_cache" => "Backup cache",
    "compatibility_mode" => "Compatibility mode",
    "console_processor" => "Console processor",
    "console_device" => "Console device",
    "memory" => "Memory",
    "minimum_memory" => "Minimum memory",
    "maximum_memory" => "Maximum memory",
    "physical_address_lines" => "Physical address lines",
    "memory_checking" => "Memory checking",
    "memory_cycle" => "Memory cycle",
    "io" => "I/O Configuration",
    "max_io_throughput" => "Maximum I/O throughput",
    "max_i/o_throughput" => "Maximum I/O throughput",
    "desc_name" => "Description",
    "firmware_version" => "Firmware version",
    "bus_sbi" => "SBI",
    "bus_unibus" => "UNIBUS",
    "bus_massbus" => "MASSBUS",
    "bus_qbus" => "Q-bus",
    "bus_vaxbi" => "VAXBI",
    "bus_xmi" => "XMI",
    "bus_lsb" => "Laserbus",
    "bus_fb" => "Futurebus",
    "bus_tc" => "TURBOchannel",
    "bus_dssi" => "DSSI",
    "bus_scsi" => "SCSI",
    "bus_pci" => "PCI",
    "bus_eisa" => "EISA",
    "bus_isa" => "ISA",
    "bus_mca" => "MCA",
    "lan_support" => "LAN support"
  }

  text = name_to_text[property.downcase().gsub('-','_')]
  raise("Failed to convert property [#{property}] to suitable text") if text.nil?()

  return text
end


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
  puts("{| BORDER='1'")
  properties.keys().each() {
    |prop|
    next if prop =~ /sys_class/i # This should be handled in some special way (VAX4000, VAX6000, UNIBUS etc.)
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
    puts("|-")
    puts("| #{tags[prop].display_text()}")
#    puts("| #{convert_property_name_to_text(prop)}")
    puts("| #{value}#{ref_text}")
  }
  puts("|}")
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
