#!/usr/bin/ruby -w

# Reads a storage definition file (e.g. disks.info) and allows production of YAML for any entries.

# Storage.create_from_info_file(info_filename)
#  Builds a Storage object from a .info file.
#  StorageDevices is a collection of Storage objects, each of which represents a single storage device entry.
#
# StorageDevices.each()
#  Allows each contained ref object to be accessed in turn.
#
# StorageDevices.encode_with(coder)
#  This is the function that is invoked when to_yaml() is called on a StorageDevices object.
#

# Encapsulates a value that comes with a reference
# 'value' is the value to keep
# 'ref' is either a single reference or an array of references. Each reference will be a key in refs.yaml i.e. EK-KA655-TM-001 rather than 1 or 2.
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
    return a.flatten()
  end

end

# Encapsulates a Storage entry
class Storage

  attr_reader :identifier
  attr_reader :line_num
  attr_reader :sys_class
  attr_reader :storage_type

  def initialize(identifier, type, sys_class, line_num, possible_tags)
    @identifier = identifier
    @line_num = line_num
    @storage_type = type
    @sys_class = VariableWithReference.new(sys_class, nil)
    @possible_tags = possible_tags
    @docs = []
    @text_block = []
    @local_references = []
  end
  
  def set_docs(docs)
    @docs = docs  # Intended to be an array
  end

  def set_local_references(refs)
    @local_references = refs # Intended to be an array
  end

  def add_text(extra_text)
    return if extra_text.empty?()
    @text_block << "" unless @text_block.empty?()
    @text_block += extra_text
  end

  def confidential(text)
    @confidential = (text =~ /^yes$/ix)
  end
  
  # This function will be called when to_yaml() encounters an object of type Storage.
  # It encodes is data as though it were a hash of:
  #   { tag e.g. "FRS-date" => [value, ref#1, ref#2] }
  #
  def encode_with(coder)
    h = {}

    # For each possible tag, if it is present, represent it in the output.
    @possible_tags.each() {
      |key|
      instance_variable_name = StorageDevices.tag_to_instance_variable_name(key)
      if self.instance_variable_defined?(instance_variable_name)
        # Use tag (i.e. the key) for the "name" and represent the value as an array with the first element as the actual value
        # and any further elements representing references.
        h[key] = self.instance_variable_get(instance_variable_name).as_array()
      end
    }

    # If @docs is present and not empty, try representing it
    h["docs"] = @docs unless @docs.nil?() || @docs.empty?()

    # If @local_references is present and not empty, try representing it
    h["local_references"] = @local_references unless @local_references.nil?() || @local_references.empty?()

    # If @text_block is present and not empty, try representing it
    h["text_block"] = @text_block unless @text_block.nil?() || @text_block.empty?()

    coder.represent_map(nil, h)
  end
end

class StorageDevices

  DATA_REFERENCES_ID = "DataReferences"

  # Turns a tag name into an instance variable name
  def self.tag_to_instance_variable_name(tag)
    ('@' + tag.downcase().gsub(%r{[-/]},'_')).to_sym()
  end

  def initialize()
    @storage = {}
  end

  def add_storage(storage)
    @storage[storage.identifier()] = storage
  end
  
  def [](identifier)
    @storage[identifier]
  end
  
  def each()
    @storage.keys().sort().each() {
      |id|
      yield id
    }
  end

  def to_yaml()
    @storage.to_yaml()
  end

  # Reads a storage .info file ...
  # storage_type_expected: type of storage device: dssi, scsi, st506 etc.
  # permitted_tags: an array of permitted tags

  def StorageDevices.create_from_info_file(info_filename, storage_type_expected, permitted_tags, refs, pubs)
    line_num = 0
    current = nil
    text_block = [] # text is kept as an array of lines
    storage_devices = StorageDevices.new()
    storage_type = storage_type_expected.downcase()
    local_refs = {}
    local_docs = {}
    local_refs_non_vref_count = {}
    permitted_tags_uc = permitted_tags.map(&:upcase)
    total_uses = 0   # local uses of unverified refs
    within_text_block = false
    fatal_error_seen = false
    IO.foreach(info_filename) {
      |line|
      line_num += 1
      line = line.chomp().strip()
      
      # Handle text-blocks
      if !current.nil?()
        if within_text_block
          # If within a text block, keep accumulating unless **Text-end seen alone on a line
          if line =~ /^\s*\*\*Text-end\s*$/i
            within_text_block = false
            current.add_text(text_block)
            text_block = []
            next
          else
            line.gsub!(/ \*\*vref \{ ([^}]+) \}/ix) {
              given_ref = $1
              # Build an array of the valid references used here
              ref_array = []
              reference = nil
              unless given_ref.nil?()
                given_ref.split(",").each() {
                  |lref|
                  reference = local_refs[lref]
                  if reference.nil?()
                    $stderr.puts("vref refers to non-existent lref{#{lref}} on line #{line_num} of #{info_filename}") 
                    fatal_error_seen = true
                  end
                  unless reference.nil?()
                    ref_array << reference
                  end
                }
              end
              rtext = ""
              ref_array.each() {|ra| rtext << "**tref{#{ra}}"}
              rtext
            }
            text_block << line
            next
          end
        elsif line =~ /^\s*\*\*Text-start\s*$/i
          # Text-start seen, so switch to text-block mode
          within_text_block = true
          next
        end
      end

      if line.strip().empty?() || line =~ /^ !/ix
        # ignore blank lines and commented out lines
        next
      elsif line =~ /^\s*\*\*Stop-processing\s*$/i
        # Stop if a line with just "**Stop-processing" is seen.
        break
      elsif line =~ /^\s*\*\*Start-storage-entry\{(.*)\}{(.*)}{(.*)}\s*$/ix
        # **Start-storage-entry{RX50}{MISC}{RX}
        id = $1.strip()
        type = $2.strip()
        sys_class = $3.strip()
        raise("Unexpected system type [#{type}], expected [#{storage_type}]") if type.downcase() != storage_type
        raise("Duplicate reference [#{id}] read in #{info_filename} at line #{line_num}: #{line} (originally #{storage_devices[id].line_num()})") unless storage_devices[id].nil?()
        current = Storage.new(id, storage_type, sys_class, line_num, permitted_tags)
        next
      elsif line =~ /\*\*End-storage-entry\{(.*)\}/ix
        # **End-storage-entry{RX50}
        # TODO - check closing the right one, then add to pile
        local_refs.keys().each() {
          |k|
          total_uses += local_refs_non_vref_count[k]
          count_text = "%3.3d" % local_refs_non_vref_count[k]
        }
        current.set_docs(local_docs.values())
        current.set_local_references(local_refs)
        storage_devices.add_storage(current)
        current = nil
        local_refs = {}  # Discard "local" references
        local_refs_non_vref_count = {}
        local_docs = {}  # Discard "local" related documents
        next
      elsif !current.nil?() && line =~ /^\s*\*\*Def-lref\{(\d+)\}\s*=\s*ref\{(.*)\}\s*$/i
        id = $1
        ref_name = $2
        ref = refs[ref_name]
        if ref.nil?()
          $stderr.puts("lref{#{id}} of [#{ref_name}] not found on line #{line_num}")
        else
          if local_refs[id].nil?()
            local_refs[id] = ref_name
            local_refs_non_vref_count[id] = 0
          else
            raise("Local ref id [#{id}] reused on line #{line_num} of #{info_filename}")
          end
        end
        next
      elsif !current.nil?() && line =~ /^\s*\*\*document\s*=\s*doc\{(.*)\}\s*(!.*)?$/i
        doc_id = $1
        doc = pubs[doc_id]
        if doc.nil?()
          $stderr.puts("Doc [#{doc_id}] not found on #{line_num} of #{info_filename}")
          fatal_error_seen = true
        elsif !local_docs[doc_id].nil?()
          $stderr.puts("Doc [#{doc_id}] repeated on #{line_num} of #{info_filename}")
          fatal_error_seen = true
        else
          # Skip documents that have no title: what could they possibly mean?
          if doc["title"].nil?()
            $stderr.puts("Doc [#{doc_id}] has no title on #{line_num} of #{info_filename}")
            fatal_error_seen = true
          else
            entry = doc["title"] + ". "
            entry += doc["part-no"] unless doc["part-no"].nil?()
            local_docs[doc_id] = entry
          end
        end
        next
      elsif line =~ /^ \s* \! /ix
        $stderr.puts("Skipping comment [#{line}]")
        # skip comment line
        next
      elsif current.nil?()
        # TODO - line outside of storage?
        next
      elsif !current.nil?() && line =~ /^\s*\*\*(Dimensions|Power)-(start|end)/i
        # TODO skipping dimensions/power
        next
      end
      
      # Here process a line within a storage entry
      if line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|lref|uref|vref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
        tag = $1
        reftype = $2
        given_ref = $3
        value = $4
        next if value =~ /^\s*@@\s*$/   # skip values of "@@" as these mean "this value is not known"
        # Build an array of the valid references used here
        ref_array = []
        reference = nil
        unless given_ref.nil?()
          given_ref.split(",").each() {
            |lref|
            reference = local_refs[lref]
            raise("vref refers to non-existent lref{#{lref}} on line #{line_num} of #{info_filename}") if reftype =~ /vref/i && reference.nil?()
            unless reference.nil?()
              local_refs_non_vref_count[lref] += 1 unless reftype =~ /vref/i  # count any reference except a vref
              ref_array << reference if reftype =~ /vref/i
            end
          }
        end
        if permitted_tags_uc.include?(tag.upcase())
          # TODO
          # At the moment Dimensions and Power are not handled properly, so skip them otherwise these tags are seen repeatedly and the checking fails
          next if ["Height","Width","Depth","Weight","Supply","I-max","Power","Heat-dissipation","Option-title","Option","Label"].include?(tag)
          # If the instance variable already exists then something has been defined twice
          instance_variable_name = StorageDevices.tag_to_instance_variable_name(tag)
          if current.instance_variable_defined?(instance_variable_name)
            raise("On line #{line_num} in #{current.identifier()}, tag #{tag} has been defined again.")
          else
            # Set the appropriate instance variable to the value+reference(s) specified
            current.instance_variable_set(instance_variable_name, VariableWithReference.new(value, ref_array))
          end
        else
          raise("On line #{line_num} in #{current.identifier()}, unknown tag [#{tag}] has been used. permitted=#{permitted_tags_uc}")
        end
      elsif line.strip().empty?()
        raise("Muffed empty line check")
      elsif line =~ /^\s*!/
        raise("Muffed comment line check")
      else
        raise("unrecognised line (at line #{line_num}) [#{line}]")
      end
    }

    raise("Stopping because of one or more above fatal errors") if fatal_error_seen

    return storage_devices
  end

end
