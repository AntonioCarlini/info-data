#!/usr/bin/ruby -w

# Reads a VAX Systems file (e.g. vax.info) and allows production of YAML for any entries.

# Systems.create_from_info_file(info_filename)
#  Builds a Systems object from a vax.info file.
#  Systems is a collection of System objects, each of which represents a single computer system entry.
#
# Systems.each()
#  Allows each contained ref object to be accessed in turn.
#
# System.encode_with(coder)
#  This is the function that is invoked when to_yaml() is called on a System object.
#

# Encapsulates a value that comes with a reference
class VariableWithReference

  attr_reader  :ref
  attr_reader  :value

  def initialize(value, ref)
    @value = value
    @ref = ref
  end

  def as_array()
    a = [ @value ]
    a << @ref unless @ref.nil?() || @ref.empty?()
    return a
  end

end

# Encapsulates a Systems entry
class System

  attr_reader :identifier
  attr_reader :sys_class
  attr_reader :sys_type

  def initialize(identifier, type, sys_class, line_num, possible_tags)
    @identifier = identifier
    @line_num = line_num
    @sys_type = type
    @sys_class = sys_class
    @possible_tags = possible_tags
  end
  
  def confidential(text)
    @confidential = (text =~ /^yes$/ix)
  end
  
  # This function will be called when to_yaml() encounters an object of type Ref.
  # It encodes is data as though it were a hash of:
  #   { identifier => {hash of relevant member variables} }
  #
  def encode_with(coder)
    h = {}
    h["sys-class"] = VariableWithReference.new(@sys_class, nil).as_array()

    # For each possible tag, it it is present, represent it in the output.
    @possible_tags.keys().each() {
      |key|
      if self.instance_variable_defined?(@possible_tags[key])
        # Use tag (i.e. the key) for the "name" and represent the value as an array with the first element as the actual value
        # and any further elements represnting references.
        h[key] = self.instance_variable_get(@possible_tags[key]).as_array()
      end
    }
    coder.represent_map(nil, h)
  end
end

class Systems

  DATA_REFERENCES_ID = "DataReferences"

  def initialize()
    @systems = {}
  end

  def add_system(system)
    @systems[system.identifier()] = system
  end
  
  def [](identifier)
    @systems[identifier]
  end
  
  def each()
    @systems.keys().sort().each() {
      |id|
      yield id
    }
  end

  def to_yaml()
    @systems.to_yaml()
  end

  # Returns a hash of {tag-name => instance-variable-name} for the given type of system.
  def tags(type)
    vax_tags = {
      "Sys-name" => :@sys_name, "Desc-name" => :@desc_name, "Codename" => :@codename,
      "Html-target" => :@html_target,
      "Announcement" => :@announcement,
      "FRS-date"=> :@frs_date, "FCS-date" => :@fcs_date,
      "Last-order" => :@last_order, "Last-ship" => :@last_ship,
      "OS-support-VMS" => :@os_support_vms, "OS-support-MDM" => :@os_support_mdm,
      "OS-support-ELN" => :@os_support_eln, "OS-support-ULTRIX" => :@os_support_ultrix,
      "CPU-module" => :@cpu_module, "Module" => :@module, "Firmware-version" => :@firmware, 
      "CPU-name-VMS" => :@cpu_name_vms, "CPU-name-console" => :@cpu_name_console,
      "VMS-CPU" => :@vms_cpu, "VMS-XCPU" => :@vms_xcpu, "SID" => :@sid, "XSID" =>:@xsid,
      "Num-proc" => :@num_proc, "CPU-chip" => :@cpu_chip, "FPU-chip" => :@fpu_chip, "CPU-clock" => :@cpu_clock,
      "CPU-cycle" => :@cpu_cycle, "Instruction-buffer" => :@instruction_buffer,
      "Translation-buffer" => :@translation_buffer,
      "Cache" => :@cache, "Primary-cache" => :@primary_cache, "Backup-cache" => :@backup_cache,
      "Secondary-Cache" => :@secondary_cache,
      "Compatibility-mode" => :@compatibility_mode,
      "Console-processor" => :@console_processor, "Console-device" => :@console_device,
      "Minimum-memory" => :@min_memory, "Maximum-memory" => :@max_memory, "on-board-memory" => :@on_board_memory,
      "Memory-checking" => :@mem_checking, "Memory-cycle" => :@memory_cycle,
      "Max-I/O-throughput" => :@max_io_thruput,
      "BUS-Qbus" => :@bus_qbus, "BUS-SCSI" => :@bus_scsi, "BUS-DSSI" => :@bus_dssi,
      "BUS-unibus" => :@bus_unibus, "BUS-vaxbi" => :@bus_vaxbi, "BUS-XMI" => :@bus_xmi, "BUS-SBI" => :@bus_sbi,
      "BUS-MASSBUS" => :@bus_massbus,
      "CPU-technology" => :@cpu_technology,
      "VUPs" => :@vups, "SPECmarks" => :@specmarks, "TPC-A" => :@tpc_a, "SPECint89" => :@specint89, "SPECfp89" => :@specfp89,
      "Physical-address-lines" => :@phys_addr_lines,
      "LAN-support" => :@lan_support,
      "CPU-names" => :@cpu_names, "Control-store" => :@control_store, "Gate-delay" => :@gate_delay,
      "Vector-processor" => :@vector_processor, "WCS" => :@wcs, "UWCS" => :@uwcs
    }

    return case type
           when /^vax$/ then vax_tags
           else raise("Unknown system type: [#{type}]")
           end
  end

  # Reads a systems .info file ...
  # sys_type_expected: type of system: vax, alpha etc.
  def Systems.create_from_info_file(info_filename, sys_type_expected)
    line_num = 0
    current = nil
    systems = Systems.new()
    sys_type = sys_type_expected.downcase()
    permitted_tags = systems.tags(sys_type) # These are the permitted tags

    IO.foreach(info_filename) {
      |line|
      line_num += 1
      line = line.chomp().strip()
      
      if line.strip().empty?() || line =~ /^ !/ix
        # ignore blank lines and commented out lines
        next
      elsif line =~ /^\s*\*\*Stop-processing\s*$/
        # Stop if a line with just "**Stop-processing" is seen.
        break
      elsif line =~ /^\s*\*\*Start-systems-entry\{(.*)\}{(.*)}{(.*)}\s*$/ix
        # **Start-systems-entry{VAX4100}{VAX}{VAX4000}
        id = $1.strip()
        type = $2.strip()
        sys_class = $3.strip()
        raise("Unexpected system type [#{type}], exepcted [#{sys_type}]") if type.downcase() != sys_type
        raise("Duplicate reference [#{id}] read in #{info_filename} at line #{line_num}: #{line} (originally #{ret[id].line_num()})") unless systems[id].nil?()
        current = System.new(id, sys_type, sys_class, line_num, permitted_tags)
        next
      elsif line =~ /\*\*End-systems-entry\{(.*)\}/ix
        # **End-systems-entry{VAX4100}
        # TODO - check closing the right one, then add to pile
        systems.add_system(current)
        current = nil
        next
      elsif !current.nil?() && line =~ /^\s*\*\*Def-lref\{\d\}\s*=\s*ref\{.*\}\s*$/i
        # TODO skipping lref for now ...
        next
      elsif line =~ / \s* \! /ix
        # skip comment line
        next
      elsif current.nil?()
        # TODO - line outside of system?
        next
      elsif !current.nil?() && line =~ /^\s*\*\*(Dimensions|Power)-(start|end)/i
        # TODO skipping dimensions/power
        next
      end
      
      # Here process a line within a systems entry
      if line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (?:htref|lref|uref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
        tag = $1
        lref = $2
        value = $3
        if permitted_tags.has_key?(tag)
          # If the instance variable already exists then something has been defined twice
          if current.instance_variable_defined?(permitted_tags[tag])
            raise("On line #{line_num} in #{current.identifier()}, tag #{tag} has been defined again.")
          else
            # Set the appropriate instance variable to the value+reference specified
            current.instance_variable_set(permitted_tags[tag], VariableWithReference.new(value, lref))
          end
        end
      elsif line.strip().empty?()
        raise("Muffed empty line check")
      elsif line =~ /^\s*!/
        raise("Muffed comment line check")
      else
        raise("unrecognised line [#{line}]")
      end
    }

    return systems
  end

end
