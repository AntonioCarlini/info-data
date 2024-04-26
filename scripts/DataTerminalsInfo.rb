#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "VariableWithReference.rb"

# Reads a terminal definition file (e.g. terminals.info) and allows production of YAML for any entries.

# TerminalsCollection.create_from_info_file(info_filename)
#  Builds a TerminalsCollection object from a .info file.
#  TerminalsCollection is a collection of Terminal objects, each of which represents a single terminal device entry.
#
# TerminalsCollection.each()
#  Allows each contained Terminal object to be accessed in turn.
#
# TerminalsCollection.encode_with(coder)
#  This is the function that is invoked when to_yaml() is called on a TerminalsCollection object.
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
# TODO: Any non-blank lines should trigger a failure, but currently they do not.
#-
class InfoFileHandlerOuter

  attr_reader     :fatal_error_seen

  def initialize(permitted_tags, info_filename, expected_entry_type, refs, devices)
    @permitted_tags = permitted_tags
    @permitted_tags_uc = @permitted_tags.map(&:upcase)
    @info_filename = info_filename
    @expected_entry_type = expected_entry_type
    @refs = refs
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
      elsif line =~ /^\s*\*\*Start-terminals-entry\{(.*)\}{(.*)}{(.*)}\s*$/ix
        # **Start-terminals-entry{RX50}{MISC}{RX}
        id = $1.strip()
        type = $2.strip()
        entry_class = $3.strip()
        raise("Unexpected system type [#{type}], expected [#{@expected_entry_type}]") if type.downcase() != @expected_entry_type
        ## TODO raise("Duplicate reference [#{id}] read in #{info_filename} at line #{line_num}: #{line} (originally #{terminal_devices[id].line_num()})") unless terminal_devices[id].nil?()
        entry = Terminal.new(id, @expected_entry_type, entry_class, line_num, @permitted_tags)
        return HandlerResult::STACK_HANDLER, InfoFileHandlerTerminal.new(entry, @info_filename, @permitted_tags_uc, @refs)
      elsif line =~ /^ \s* \! /ix
        # TODO why is this here .. .why can this not be handled above?
        $stderr.puts("Skipping comment [#{line}]")
        # skip comment line
        return HandlerResult::CONTINUE, nil
      else
        # TODO - line outside of terminal? - this should FAIL
        return HandlerResult::CONTINUE, nil
      end
  end
  
  # TODO this should be invoked with a InfoFileHandlerTerminal
  def process_sub_handler(sub_handler)
    @devices.add_terminal(sub_handler.entry())  # TODO actually this should be passed to the handler that caused it to be invoked
  end
  
end

#+
# The InfoFileHandlerTerminal class handles everything from a start-terminals-entry to an end-terminals-entry.
# It will skip empty lines and those that have only a comment and it will hand over to another handler if a valid start-ABC-entry is seen.
# TODO: Any non-blank lines should trigger a failure, but currently they do not.
#-

class InfoFileHandlerTerminal

  attr_reader     :entry
  attr_reader     :fatal_error_seen
  
  def initialize(entry, info_filename, permitted_tags_uc, refs)
    @fatal_error_seen = false
    @permitted_tags_uc = permitted_tags_uc
    @info_filename = info_filename
    @local_refs = {}
    @local_docs = {}
    @local_refs_non_vref_count = {}
    @entry = entry
    @refs = refs
  end

  def process_line(line, line_num)
    if line =~ /\*\*End-terminals-entry\{(.*)\}/ix
      # **End-terminal-entry{RX50}
      # TODO - check closing the right one, then add to pile
      @local_refs.keys().each() {
        |k|
        ## TODO is this needed total_uses += @local_refs_non_vref_count[k]
        count_text = "%3.3d" % @local_refs_non_vref_count[k]
      }
      @entry.set_docs(@local_docs.values())
      @entry.set_local_references(@local_refs)
      return HandlerResult::COMPLETED, @entry
    elsif line =~ /^\s*\*\*Def-lref\{(\d+)\}\s*=\s*ref\{(.*)\}\s*$/i
      id = $1
      ref_name = $2
      # Have a function handle Def-lref
      process_local_reference_definition(line_num, id, ref_name)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*document\s*=\s*doc\{(.*)\}\s*(!.*)?$/i
      doc_id = $1
      doc = pubs[doc_id]
      process_document_declaration(doc_id, doc)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*Text-start\s*$/i
      # Text-start seen, so switch to text-block mode
      # TODO: need to handle this properly but start by ignoring it!
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|lref|uref|vref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
      tag = $1
      ref_type = $2
      given_ref = $3
      value = $4
      process_value(line_num, tag, ref_type, given_ref, value)
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
        raise("vref refers to non-existent lref{#{lref}} on line #{line_num} of #{@info_filename}") if ref_type =~ /vref/i && reference.nil?()
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
      # If the instance variable already exists then something has been defined twice
      instance_variable_name = TerminalsCollection.tag_to_instance_variable_name(tag)
      if @entry.instance_variable_defined?(instance_variable_name)
        raise("On line #{line_num} in #{current.identifier()}, tag #{tag} has been defined again.")
      else
        # Set the appropriate instance variable to the value+reference(s) specified
        @entry.instance_variable_set(instance_variable_name, VariableWithReference.new(value, ref_array))
      end
    else
      $stderr.puts("On line #{line_num} in #{current.identifier()}, unknown tag [#{tag}] has been used. permitted=#{permitted_tags_uc}")
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
      $stderr.puts("Doc [#{doc_id}] not found on #{line_num} of #{@info_filename}")
      fatal_error_seen = true
    elsif !local_docs[doc_id].nil?()
      $stderr.puts("Doc [#{doc_id}] repeated on #{line_num} of #{@info_filename}")
      fatal_error_seen = true
    else
      # Skip documents that have no title: what could they possibly mean?
      if doc["title"].nil?()
        $stderr.puts("Doc [#{doc_id}] has no title on #{line_num} of #{@info_filename}")
        fatal_error_seen = true
      else
        entry = doc["title"] + ". "
        entry += doc["part-no"] unless doc["part-no"].nil?()
        local_docs[doc_id] = entry
      end
    end
  end
  
end

# Encapsulates a Terminal entry
class Terminal

  attr_reader :identifier
  attr_reader :line_num
  attr_reader :sys_class
  attr_reader :terminal_type

  def initialize(identifier, type, sys_class, line_num, possible_tags)
    @identifier = identifier
    @line_num = line_num
    @terminal_type = type
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

  # This function will be called when to_yaml() encounters an object of type Terminal.
  # It encodes is data as though it were a hash of:
  #   { tag e.g. "FRS-date" => [value, ref#1, ref#2] }
  #
  def encode_with(coder)
    h = {}

    # For each possible tag, if it is present, represent it in the output.
    @possible_tags.each() {
      |key|
      instance_variable_name = TerminalsCollection.tag_to_instance_variable_name(key)
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

class TerminalsCollection

  DATA_REFERENCES_ID = "DataReferences"

  # Turns a tag name into an instance variable name
  def self.tag_to_instance_variable_name(tag)
    ('@' + tag.downcase().gsub(%r{[-/]},'_')).to_sym()
  end

  def initialize()
    @terminals = {}
  end

  def add_terminal(terminal)
    @terminals[terminal.identifier()] = terminal
  end
  
  def [](identifier)
    @terminals[identifier]
  end
  
  def each()
    @terminals.keys().sort().each() {
      |id|
      yield id
    }
  end

  def to_yaml()
    @terminals.to_yaml()
  end

  # Reads a terminal .info file and processes it.
  #
  # info_filename: the filepath of the .info file
  # type_expected: type of device: decvt etc.
  # permitted_tags: an array of permitted tags
  # refs: references (from refs.info)
  # refs: publications (from pubs.info)
  def TerminalsCollection.create_from_info_file(info_filename, type_expected, permitted_tags, refs, pubs)
    fatal_error_seen = false
    line_num = 0
    devices = TerminalsCollection.new()
    ## TODO total_uses = 0   # local uses of unverified refs
    within_text_block = false

    handlers = [ InfoFileHandlerOuter.new(permitted_tags, info_filename, type_expected, refs, devices) ]
    IO.foreach(info_filename) {
      |line|
      current_handler = handlers[-1]
      line_num += 1
      line = line.chomp().strip()
      result, extra = current_handler.process_line(line, line_num)
      case result
      when HandlerResult::IMMEDIATE_STOP
        raise("saw unhandled result: IMMEDIATE_STOP for #{line_num}: [#{line}]")
      when HandlerResult::CONTINUE
        $stderr.puts("saw CONTINUE for #{line_num}: [#{line}]")
      when HandlerResult::STACK_HANDLER
        # Use replacement handler
        handlers << extra
        current_handler = extra
        $stderr.puts("processed result: STACK_HANDLER for #{line_num}: [#{line}]")
      when HandlerResult::COMPLETED
        fatal_error_seen = true if current_handler.fatal_error_seen()
        handlers.pop()
        handlers[-1].process_sub_handler(current_handler)  # TODO actually this should be passed to the handler that caused it to be invoked
        $stderr.puts("saw  result: COMPLETED for #{line_num}: [#{line}]")
      end
    }

    raise("Stopping because of one or more above fatal errors") if fatal_error_seen

    return devices
  end

end
