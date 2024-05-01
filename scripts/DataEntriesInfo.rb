#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "VariableWithReference.rb"

# Reads a definition file (e.g. terminals.info) and allows production of YAML for any entries.

# EntriesCollection.create_from_info_file(info_filename)
#  Builds a EntriesCollection object from a .info file.
#  EntriesCollection is a collection of Entry objects, each of which represents a single device entry.
#
# EntriesCollection.each()
#  Allows each contained Entry object to be accessed in turn.
#
# EntriesCollection.encode_with(coder)
#  This is the function that is invoked when to_yaml() is called on a EntriesCollection object.
#

module HandlerResult
  IMMEDIATE_STOP = 0
  CONTINUE = 1
  STACK_HANDLER = 2
  COMPLETED = 3
end

#+
# The InfoFileHandlerOuter class handles the outer layer of a .info file, i.e. everything that does not lie inside a valid start-ABC-entry/end-ABC-entry pair.
# It will skip empty lines and those that have only a comment and it will hand over to another handler if a valid start-ABC-entry is seen.
#-
class InfoFileHandlerOuter

  attr_reader     :fatal_error_seen

  def initialize(permitted_tags, info_filename, expected_entry_type, refs, pubs, devices)
    @permitted_tags = permitted_tags
    @permitted_tags_uc = @permitted_tags.map(&:upcase)
    @info_filename = info_filename
    @expected_entry_type = expected_entry_type
    @refs = refs
    @pubs = pubs
    @fatal_error_seen = false
    @devices  = devices
  end

  def process_line(line, line_num)
      if line.strip().empty?() || line =~ /^ !/ix
        # ignore blank lines and commented out lines
        return HandlerResult::CONTINUE, nil
      elsif line =~ /^\s*\*\*Stop-processing\s*$/i
        # Stop if a line with just "**Stop-processing" is seen.
        return HandlerResult::IMMEDIATE_STOP, nil
      elsif line =~ /^\s*\*\*Start-(.*?)-entry\{(.*)\}{(.*)}{(.*)}\s*$/ix
        # **Start-terminals-entry{RX50}{MISC}{RX}
        entry_name = $1.strip()
        id = $2.strip()
        type = $3.strip()
        entry_class = $4.strip()
        ## TODO raise("Unexpected system type [#{type}], expected [#{@expected_entry_type}]") if type.downcase() != @expected_entry_type
        ## TODO restrict to 'terminals' raise("Only 'terminals' allowed for now: rejecting '#{entry_name}'") if entry_name != "terminals"
        entry = Entry.new(id, @expected_entry_type, entry_class, line_num, @permitted_tags)
        return HandlerResult::STACK_HANDLER, InfoFileHandlerEntry.new(entry, entry_name, @info_filename, @permitted_tags_uc, @refs, @pubs)
      elsif line =~ /^ \s* \! /ix
        # TODO why is this here .. .why can this not be handled above?
        $stderr.puts("Skipping comment [#{line}]")
        # skip comment line
        return HandlerResult::CONTINUE, nil
      else
        $stderr.puts("FATAL_ERROR: Unknown contents outside of entry on line #{line_num} in #{@info_filename} [#{line}]")
        @fatal_error_seen = true
        return HandlerResult::CONTINUE, nil
      end
  end
  
  # This should be invoked with a InfoFileHandlerEntry. Anything else is an error.
  def process_sub_handler(sub_handler)
    if sub_handler.respond_to?(:entry)
      @devices.add_entry(sub_handler.entry())  # TODO actually this should be passed to the handler that caused it to be invoked
    else
      raise("Expecting object with .entry() but handed #{sub_handler.class.name()}")
    end
  end

  # Just by defining this function, we are saying that '**stop-processing' is valid here.
  # Any handler that processes lines within an entry will *not* have this defined and so will signal a fatal error.
  def stop_processing_is_valid()
  end
end

#+
# The InfoFileHandlerEntry class handles everything from a 'start-???-entry' to a matching 'end-???-entry'.
# It will skip empty lines and those that have only a comment and it will hand over to another handler if a valid start-ABC-entry is seen.
# TODO: Any non-blank lines should trigger a failure, but currently they do not.
#-
class InfoFileHandlerEntry

  attr_reader     :entry
  attr_reader     :fatal_error_seen
  
  def initialize(entry, entry_name, info_filename, permitted_tags_uc, refs, pubs)
    @fatal_error_seen = false
    @permitted_tags_uc = permitted_tags_uc
    @info_filename = info_filename
    @local_refs = {}
    @local_docs = {}
    @local_refs_non_vref_count = {}
    @entry = entry
    @entry_name = entry_name
    @refs = refs
    @pubs = pubs
    @power = []
  end

  def process_line(line, line_num)
    if line =~ /\*\*End-#{@entry_name}-entry\{(.*)\}/ix
      # e.g. **End-storage-entry{RX50}
      end_id = $1.strip()
      if end_id != @entry.identifier()
        $stderr.puts("FATAL_ERROR: On line #{line_num} **end-#{@entry_name}-entry\{#{end_id}\} does not match **start-#{@entry_name}-entry\{#{@entry.identifier()}\}") if end_id != @entry.identifier()
        @fatal_error_seen = true
      end
      @local_refs.keys().each() {
        |k|
        ## TODO is this needed? total_uses += @local_refs_non_vref_count[k]
        count_text = "%3.3d" % @local_refs_non_vref_count[k]
      }
      @entry.set_docs(@local_docs.values())
      @entry.set_local_references(@local_refs)
      return HandlerResult::COMPLETED, nil
    elsif line =~ /^\s*\*\*Def-lref\{(\d+)\}\s*=\s*ref\{(.*)\}\s*$/i
      id = $1
      ref_name = $2
      # Have a function handle Def-lref
      process_local_reference_definition(line_num, id, ref_name)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*document\s*=\s*doc\{(.*)\}\s*(!.*)?$/i
      doc_id = $1
      doc = @pubs[doc_id]
      process_document_declaration(line_num, doc_id, doc)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*Text-start\s*$/i
      # Text-start seen, so switch to text-block mode
      return HandlerResult::STACK_HANDLER, InfoFileHandlerText.new(@local_refs)
    elsif line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|lref|uref|vref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
      tag = $1
      ref_type = $2
      given_ref = $3
      value = $4
      process_value(line_num, tag, ref_type, given_ref, value)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*Power-start\{(.*?)\}/ix
      # Text-start seen, so switch to power-block mode
      id = $1.strip()
      return HandlerResult::STACK_HANDLER, InfoFileHandlerPower.new(id, @info_filename, line_num, @local_refs, @refs, @pubs)
    elsif line =~ /^\*\*(Dimensions|Power)-(start|end)\{/ix
      # Ignore Power and Dimensions for now
      return HandlerResult::CONTINUE, nil
    elsif line.strip().empty?() || line =~ /^\s*!/ix
        # ignore blank lines and commented out lines
      return HandlerResult::CONTINUE, nil
    else
      $stderr.puts("FATAL ERROR: Invalid line #{line_num}: #{line}")
      @fatal_error_seen = true
      return HandlerResult::CONTINUE, nil
    end
  end
  
  def process_value(line_num, tag, ref_type, given_ref, value)
    # skip values of "@@" as these mean "this value is not known"
    return if value =~ /^\s*@@\s*$/

    # Build an array of the valid references used here
    ref_array = []
    reference = nil
    unless given_ref.nil?()
      given_ref.split(",").each() {
        |lref|
        reference = @local_refs[lref]
        if ref_type =~ /vref/i && reference.nil?()
          $stderr.puts("vref refers to non-existent lref{#{lref}} on line #{line_num} of #{@info_filename}")
          @fatal_error_seen = true
          return
        end
        unless reference.nil?()
          @local_refs_non_vref_count[lref] += 1 unless ref_type =~ /vref/i  # count any reference except a vref
          ref_array << reference if ref_type =~ /vref/i
        end
      }
    end
    if @permitted_tags_uc.include?(tag.upcase())
      # TODO
      # At the moment Dimensions and Power are not handled properly, so skip them otherwise these tags are seen repeatedly and the checking fails
      return if ["Height","Width","Depth","Weight","Supply","I-max","Power","Heat-dissipation","Option-title","Option","Label"].include?(tag)
      return if ["Dimensions-start","Dimensions-end"].include?(tag)
      # If the instance variable already exists then something has been defined twice
      instance_variable_name = EntriesCollection.tag_to_instance_variable_name(tag)
      if @entry.instance_variable_defined?(instance_variable_name)
        raise("On line #{line_num} in #{@entry.identifier()}, tag #{tag} has been defined again.")
      else
        # Set the appropriate instance variable to the value+reference(s) specified
        @entry.instance_variable_set(instance_variable_name, VariableWithReference.new(value, ref_array))
      end
    else
      $stderr.puts("FATAL ERROR: On line #{line_num} in #{@entry.identifier()}, unknown tag [#{tag}] has been used. permitted=#{@permitted_tags_uc}")
      @fatal_error_seen = true
    end
  end
  
  def process_local_reference_definition(line_num, id, ref_name)
    ref = @refs[ref_name]
    if ref.nil?()
      $stderr.puts("lref{#{id}} of [#{ref_name}] not found on line #{line_num}")
    else
      if @local_refs[id].nil?()
        @local_refs[id] = ref_name
        @local_refs_non_vref_count[id] = 0
      else
        raise("Local ref id [#{id}] reused on line #{line_num} of #{@info_filename}")
      end
    end
  end
  
  def process_document_declaration(line_num, doc_id, doc)
    # Have a function process 'document'
    if doc.nil?()
      $stderr.puts("FATAL ERROR: Doc [#{doc_id}] not found on #{line_num} of #{@info_filename}")
      fatal_error_seen = true
    elsif !@local_docs[doc_id].nil?()
      $stderr.puts("FATAL ERROR: Doc [#{doc_id}] repeated on #{line_num} of #{@info_filename}")
      @fatal_error_seen = true
    else
      # Skip documents that have no title: what could they possibly mean?
      if doc["title"].nil?()
        $stderr.puts("FATAL ERROR: Doc [#{doc_id}] has no title on #{line_num} of #{@info_filename}")
        @fatal_error_seen = true
      else
        entry = doc["title"] + ". "
        entry += doc["part-no"] unless doc["part-no"].nil?()
        @local_docs[doc_id] = entry
      end
    end
  end
  
  # Currently this should only be invoked with an object of type InfoFileHandlerText
  def process_sub_handler(sub_handler)
    if sub_handler.respond_to?(:text_block)
      @entry.add_text(sub_handler.text_block())
    elsif sub_handler.respond_to?(:power)
      # If a second power block is being added, report if the first has no label
      if (@power.size() == 1) and !@power[0].label_defined?()
        $stderr.puts("Power block #{@power[0].identifier()} starting on line #{@power[0].line_num} has no label")
        @fatal_error_seen = true
      end
      # If any block after the first is being added, report if it does not have a label
      power = sub_handler.power()
      if !power.label_defined? and @power.size() > 1
        $stderr.puts("Power block #{power.identifier()} starting on line #{power.line_num} has no label, but needs one")
        @fatal_error_seen = true
      end     
      @power << power
    else
      raise("Expecting object with .text_block() but handed #{sub_handler.class.name()}")
    end
  end
end

#+
# The InfoFileHandlerText class handles free form text.
# Text of the form '**vref{N}' will be turned into that specific reference , but everything else will be left untouched.
#-
class InfoFileHandlerText

  attr_reader     :fatal_error_seen
  attr_reader     :text_block

  def initialize(local_refs)
    @local_refs = local_refs
    @text_block = []
    @fatal_error_seen = false
  end

  def process_line(line, line_num)
    if line =~ /^\s*\*\*Text-end\s*$/i
      return HandlerResult::COMPLETED, nil
    else
      line.gsub!(/ \*\*vref \{ ([^}]+) \}/ix) {
        given_ref = $1
        # Build an array of the valid references used here
        ref_array = []
        reference = nil
        unless given_ref.nil?()
          given_ref.split(",").each() {
            |lref|
            reference = @local_refs[lref]
            if reference.nil?()
              $stderr.puts("FATAL ERROR: vref refers to non-existent lref{#{lref}} on line #{line_num} of #{info_filename}") 
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
      @text_block << line
    end
    return HandlerResult::CONTINUE, nil
  end
end

#+
# The InfoFileHandlerPower class handles a block of declarations representing power information.
#-
class InfoFileHandlerPower

  attr_reader     :entry
  attr_reader     :fatal_error_seen
  attr_reader     :power

  def initialize(id, info_filename, line_num, local_refs, refs, pubs)
    @fatal_error_seen = false
    @id = id
    @info_filename = info_filename
    @local_refs = local_refs
    @local_refs_non_vref_count = {}
    @refs = refs
    @pubs = pubs
    permitted_tags = DataTags.new('scripts/power-tags.yaml', 'systems', 'decvt').tags()  ## TODO hard-coded filename for now
    @permitted_tags_uc = permitted_tags.map(&:upcase)
    @power = Power.new(@id, line_num, permitted_tags)
  end

  def process_line(line, line_num)
    if line =~ /\*\*Power-end\{(.*)\}/ix
      # e.g. **Power-end{VT100KBD}
      end_id = $1.strip()
      if end_id != @id
        $stderr.puts("FATAL_ERROR: On line #{line_num} **Power-end\{#{end_id}\} does not match **Power-start\{#{@id}\}") if end_id != @id
        @fatal_error_seen = true
      end
      @local_refs.keys().each() {
        |k|
        ## TODO is this needed? total_uses += @local_refs_non_vref_count[k]
        ## TOOD count_text = "%3.3d" % @local_refs_non_vref_count[k]
      }
      return HandlerResult::COMPLETED, nil
    elsif line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|lref|uref|vref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
      tag = $1
      ref_type = $2
      given_ref = $3
      value = $4
      process_value(line_num, tag, ref_type, given_ref, value)
      return HandlerResult::CONTINUE, nil
    elsif line.strip().empty?() || line =~ /^\s*!/ix
        # ignore blank lines and commented out lines
      return HandlerResult::CONTINUE, nil
    else
      $stderr.puts("FATAL ERROR: Invalid line #{line_num}: #{line}")
      @fatal_error_seen = true
      return HandlerResult::CONTINUE, nil
    end
  end
  
  def process_value(line_num, tag, ref_type, given_ref, value)
    # skip values of "@@" as these mean "this value is not known"
    return if value =~ /^\s*@@\s*$/

    # Build an array of the valid references used here
    ref_array = []
    reference = nil
    unless given_ref.nil?()
      given_ref.split(",").each() {
        |lref|
        reference = @local_refs[lref]
        if ref_type =~ /vref/i && reference.nil?()
          $stderr.puts("vref refers to non-existent lref{#{lref}} on line #{line_num} of #{@info_filename}")
          @fatal_error_seen = true
          return
        end
        unless reference.nil?()
          ## TODO @local_refs_non_vref_count[lref] += 1 unless ref_type =~ /vref/i  # count any reference except a vref
          ref_array << reference if ref_type =~ /vref/i
        end
      }
    end
    if @permitted_tags_uc.include?(tag.upcase())
      # TODO
      # At the moment Dimensions and Power are not handled properly, so skip them otherwise these tags are seen repeatedly and the checking fails
      ## TOOD return if ["Height","Width","Depth","Weight","Supply","I-max","Power","Heat-dissipation","Option-title","Option","Label"].include?(tag)
      ## TODO return if ["Power-start","Power-end","Dimensions-start","Dimensions-end"].include?(tag)
      # If the instance variable already exists then something has been defined twice
      instance_variable_name = EntriesCollection.tag_to_instance_variable_name(tag)
      if @entry.instance_variable_defined?(instance_variable_name)
        raise("On line #{line_num} in #{@entry.identifier()}, tag #{tag} has been defined again.")
      else
        # Set the appropriate instance variable to the value+reference(s) specified
        @power.instance_variable_set(instance_variable_name, VariableWithReference.new(value, ref_array))
      end
    else
      $stderr.puts("FATAL ERROR: On line #{line_num} in #{@id}, unknown tag [#{tag}] has been used. permitted=#{@permitted_tags_uc}")
      ## TODO @fatal_error_seen = true
    end
  end
  
  # Currently this should only be invoked with an object of type InfoFileHandlerText
  def process_sub_handler(sub_handler)
    raise("No sub block expected but handed #{sub_handler.class.name()}")
  end
end

# Encapsulates a Power block
class Power

  attr_reader     :identifier
  attr_reader     :line_num
  
  def initialize(identifier, line_num, possible_tags)
    @identifier = identifier
    @line_num = line_num
    @possible_tags = possible_tags
  end

  def label_defined?()
    return self.instance_variable_defined?("@label")
  end
  
end

# Encapsulates an Entry
class Entry

  attr_reader :identifier
  attr_reader :line_num
  attr_reader :sys_class
  attr_reader :entry_type

  def initialize(identifier, type, sys_class, line_num, possible_tags)
    @identifier = identifier
    @line_num = line_num
    @entry_type = type
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

  # This function will be called when to_yaml() encounters an object of type Entry.
  # It encodes its data as though it were a hash of:
  #   { tag e.g. "FRS-date" => [value, ref#1, ref#2] }
  #
  def encode_with(coder)
    h = {}

    # For each possible tag, if it is present, represent it in the output.
    @possible_tags.each() {
      |key|
      instance_variable_name = EntriesCollection.tag_to_instance_variable_name(key)
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

class EntriesCollection

  DATA_REFERENCES_ID = "DataReferences"

  # Turns a tag name into an instance variable name
  def self.tag_to_instance_variable_name(tag)
    ('@' + tag.downcase().gsub(%r{[-/]},'_')).to_sym()
  end

  def initialize()
    @entries = {}
  end

  def add_entry(entry)
    @entries[entry.identifier()] = entry
  end
  
  def [](identifier)
    @entries[identifier]
  end
  
  def each()
    @entries.keys().sort().each() {
      |id|
      yield id
    }
  end

  def to_yaml()
    @entries.to_yaml()
  end

  # Reads an .info file and processes it.
  #
  # info_filename: the filepath of the .info file
  # type_expected: type of device: decvt etc.
  # permitted_tags: an array of permitted tags
  # refs: references (from refs.info)
  # refs: publications (from pubs.info)
  def EntriesCollection.create_from_info_file(info_filename, type_expected, permitted_tags, refs, pubs)
    fatal_error_seen = false
    line_num = 0
    devices = EntriesCollection.new()
    ## TODO total_uses = 0   # local uses of unverified refs
    within_text_block = false

    handlers = [ InfoFileHandlerOuter.new(permitted_tags, info_filename, type_expected, refs, pubs, devices) ]
    IO.foreach(info_filename) {
      |line|
      current_handler = handlers[-1]
      line_num += 1
      line = line.chomp().strip()
      result, extra = current_handler.process_line(line, line_num)
      case result
      when HandlerResult::IMMEDIATE_STOP
        if current_handler.respond_to?(:stop_processing_is_valid)
          fatal_error_seen = true if current_handler.fatal_error_seen()
          break
        else
          raise("Saw IMMEDIATE_STOP inside an entry: line #{line_num}: [#{line}]")
        end
      when HandlerResult::CONTINUE
        # $stderr.puts("saw CONTINUE for #{line_num}: [#{line}]")
      when HandlerResult::STACK_HANDLER
        # Use replacement handler
        handlers << extra
        current_handler = extra
        # $stderr.puts("processed result: STACK_HANDLER for #{line_num}: [#{line}]")
      when HandlerResult::COMPLETED
        fatal_error_seen = true if current_handler.fatal_error_seen()
        handlers.pop()
        handlers[-1].process_sub_handler(current_handler)  # TODO actually this should be passed to the handler that caused it to be invoked
        # $stderr.puts("saw  result: COMPLETED for #{line_num}: [#{line}]")
      else
        raise("saw UNKNOWN result: #{result} for line #{line_num}: [#{line}]")
      end
    }

    # Here the end of the file has been reached or **stop-processing was seen.
    # Either way, there should be one handler on the stack and it should be the Outer one
    # (which is the only one that allows **stop-processing).
    if (handlers.size() > 1) or !handlers[0].respond_to?(:stop_processing_is_valid)
      $stderr.puts("Finished processing mid-entry for file #{info_filename}")
      fatal_error_seen = true
    elsif handlers[0].fatal_error_seen()
      fatal_error_seen = true           # Catch the Outer handler's fatal error if one has been seen
    end

    raise("FATAL ERROR: Stopping because of one or more above fatal errors") if fatal_error_seen

    return devices
  end

end
