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
    @sys_class = VariableWithReference.new(sys_class, nil)
    @possible_tags = possible_tags
  end
  
  def confidential(text)
    @confidential = (text =~ /^yes$/ix)
  end
  
  # This function will be called when to_yaml() encounters an object of type System.
  # It encodes is data as though it were a hash of:
  #   { tag e.g. "FRS-date" => [value, ref#1, ref#2] }
  #
  def encode_with(coder)
    h = {}

    # For each possible tag, it it is present, represent it in the output.
    @possible_tags.each() {
      |key|
      instance_variable_name = Systems.tag_to_instance_variable_name(key)
      if self.instance_variable_defined?(instance_variable_name)
        # Use tag (i.e. the key) for the "name" and represent the value as an array with the first element as the actual value
        # and any further elements representing references.
        h[key] = self.instance_variable_get(instance_variable_name).as_array()
      end
    }
    coder.represent_map(nil, h)
  end
end

class Systems

  DATA_REFERENCES_ID = "DataReferences"

  # Turns a tag name into an instance variable name
  def self.tag_to_instance_variable_name(tag)
    ('@' + tag.downcase().gsub(%r{[-/]},'_')).to_sym()
  end

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

  # Reads a systems .info file ...
  # sys_type_expected: type of system: vax, alpha etc.
  # permitted_tags: an array of permitted tags

  def Systems.create_from_info_file(info_filename, sys_type_expected, permitted_tags, refs)
    line_num = 0
    current = nil
    systems = Systems.new()
    sys_type = sys_type_expected.downcase()
    local_refs = {}
    permitted_tags_uc = permitted_tags.map(&:upcase)
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
        raise("Unexpected system type [#{type}], expected [#{sys_type}]") if type.downcase() != sys_type
        raise("Duplicate reference [#{id}] read in #{info_filename} at line #{line_num}: #{line} (originally #{ret[id].line_num()})") unless systems[id].nil?()
        current = System.new(id, sys_type, sys_class, line_num, permitted_tags)
        next
      elsif line =~ /\*\*End-systems-entry\{(.*)\}/ix
        # **End-systems-entry{VAX4100}
        # TODO - check closing the right one, then add to pile
        systems.add_system(current)
        current = nil
        local_refs = {}  # Discard "local" references
        next
      elsif !current.nil?() && line =~ /^\s*\*\*Def-lref\{(\d)\}\s*=\s*ref\{(.*)\}\s*$/i
        id = $1
        ref_name = $2
        ref = refs[ref_name]
        if ref.nil?()
          $stderr.puts("lref{#{id}} of [#{ref_name}] not found on line #{line_num}")
        else
          if local_refs[id].nil?()
            local_refs[id] = ref_name
          else
            $stderr.puts("Local ref id [#{id}] reused on line #{line_num}")
          end
        end
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
      if line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|lref|uref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
        tag = $1
        reftype = $2
        lref = $3
        value = $4
        next if value =~ /^\s*@@\s*$/   # skip values of "@@" as these mean "this value is not known"
        reference = nil
        unless lref.nil?()
          reference = local_refs[lref]
          if reference.nil?()
            lref = nil
          else
            lref = reference
          end
        end
        if permitted_tags_uc.include?(tag.upcase())
          # TODO
          # At the moment Dimensions and Power are not handled properly, so skip them otherwise these tags are seen repeatedly and the checking fails
          next if ["Height","Width","Depth","Weight","Supply","I-max","Power","Heat-dissipation","Option-title","Option","Label"].include?(tag)
          # If the instance variable already exists then something has been defined twice
          instance_variable_name = Systems.tag_to_instance_variable_name(tag)
          if current.instance_variable_defined?(instance_variable_name)
            raise("On line #{line_num} in #{current.identifier()}, tag #{tag} has been defined again.")
          else
            # Set the appropriate instance variable to the value+reference specified
            current.instance_variable_set(instance_variable_name, VariableWithReference.new(value, lref))
          end
        else
          raise("On line #{line_num} in #{current.identifier()}, unknown tag #{tag} has been used.")
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
