#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "InfoFileHandlerDimensions.rb"
require_relative "InfoFileHandlerOptions.rb"
require_relative "InfoFileHandlerPower.rb"
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

# Function to simplify logging of fatal errors
def log_fatal(this, line_num, filename, text)
  $stderr.puts("FATAL ERROR from #{this.class().name()}: line #{line_num} in #{filename}: #{text}")
  this.fatal_error_seen = true
end

# Function to simplify logging of debug
def log_debug(this, line_num, filename, text)
  # $stderr.puts("DEBUG from #{this.class().name()}: line #{line_num} in #{filename}: #{text}")
end

#+
# The InfoFileHandlerOuter class handles the outer layer of a .info file, i.e. everything that does not lie inside a valid start-ABC-entry/end-ABC-entry pair.
# It will skip empty lines and those that have only a comment and it will hand over to another handler if a valid start-ABC-entry is seen.
#-
class InfoFileHandlerOuter

  attr_accessor     :fatal_error_seen

  def initialize(tags, info_filename, expected_entry_type, refs, pubs, devices)
    @tags = tags
    @info_filename = info_filename
    @expected_entry_type = expected_entry_type
    @refs = refs
    @pubs = pubs
    @fatal_error_seen = false
    @devices  = devices
    @allow_only_vref = false
  end

  def process_line(line, line_num)
      if line.strip().empty?() || line =~ /^ !/ix
        # ignore blank lines and commented out lines
        return HandlerResult::CONTINUE, nil
      elsif line =~ /^\s*\*\*Stop-processing\s*$/i
        # Stop if a line with just "**Stop-processing" is seen.
        return HandlerResult::IMMEDIATE_STOP, nil
      elsif line =~ /^\s*\*\*References-must-be-verified\s*$/i
        # Force all future references to be verified
        @allow_only_vref = true
        return HandlerResult::CONTINUE, nil
      elsif line =~ /^\s*\*\*Start-(.*?)-entry\{(.*)\}{(.*)}{(.*)}\s*$/ix
        # **Start-terminals-entry{RX50}{MISC}{RX}
        entry_name = $1.strip()
        id = $2.strip()
        type = $3.strip()
        entry_class = $4.strip()
        ## TODO raise("Unexpected system type [#{type}], expected [#{@expected_entry_type}]") if type.downcase() != @expected_entry_type
        ## TODO restrict to 'terminals' raise("Only 'terminals' allowed for now: rejecting '#{entry_name}'") if entry_name != "terminals"
        entry = Entry.new(id, @expected_entry_type, entry_class, line_num, @tags)
        return HandlerResult::STACK_HANDLER, InfoFileHandlerEntry.new(entry, entry_name, @info_filename, @tags, @refs, @pubs, @allow_only_vref)
      elsif line =~ /^ \s* \! /ix
        # TODO why is this here .. .why can this not be handled above?
        log_debug(self, line_num, @info_filename, "Skipping comment [#{line}]")
        # skip comment line
        return HandlerResult::CONTINUE, nil
      else
        log_fatal(self, line_num, @info_filename, "Unknown contents outside of entry: [#{line}]")
        @fatal_error_seen = true
        return HandlerResult::CONTINUE, nil
      end
  end

  # This should be invoked with a InfoFileHandlerEntry. Anything else is an error.
  def process_sub_handler(sub_handler)
    if sub_handler.respond_to?(:entry)
      result = @devices.add_entry(sub_handler.entry(), sub_handler.entry().line_num(), @info_filename)
      @fatal_error_seen if result == nil
    else
      raise("Expecting object with .entry() but handed #{sub_handler.class.name()}")
    end
  end

  # Just by defining this function, we are saying that '**stop-processing' is valid for this handler.
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
  attr_accessor   :fatal_error_seen

  def initialize(entry, entry_name, info_filename, tags, refs, pubs, allow_only_vref)
    @fatal_error_seen = false
    @tags = tags
    @permitted_tags_uc = @tags.tags_uc()
    @info_filename = info_filename
    @local_refs = {}
    @local_docs = {}
    @local_refs_non_vref_count = {}
    @entry = entry
    @entry_name = entry_name
    @refs = refs
    @pubs = pubs
    @power = []
    @dimensions = []
    @options = []
    @allow_only_vref = allow_only_vref
  end

  def process_line(line, line_num)
    if line =~ /\*\*End-#{@entry_name}-entry\{(.*)\}/ix
      # e.g. **End-storage-entry{RX50}
      end_id = $1.strip()
      if end_id != @entry.identifier()
        log_fatal(self, line_num, @info_filename, "**end-#{@entry_name}-entry\{#{end_id}\} does not match **start-#{@entry_name}-entry\{#{@entry.identifier()}\}") if end_id != @entry.identifier()
        @fatal_error_seen = true
      end
      @local_refs.keys().each() {
        |k|
        ## TODO is this needed? total_uses += @local_refs_non_vref_count[k]
        count_text = "%3.3d" % @local_refs_non_vref_count[k]
      }
      @entry.set_docs(@local_docs.values())
      @entry.set_local_references(@local_refs)
      @entry.set_power(@power)
      @entry.set_dimensions(@dimensions)
      @entry.set_options(@options)
      # Put in some sanity checks: both Sys-name and Desc-name must be present
      sys_name = @entry.instance_variable_get("@sys_name")
      log_fatal(self, line_num, @info_filename, "Sys-name missing for #{entry.identifier()}") if sys_name.nil?() || sys_name.value().empty?()
      raise("Sys-name missing for #{entry.identifier()}") if sys_name.nil?() || sys_name.value().empty?()
      desc_name = @entry.instance_variable_get("@desc_name")
      log_fatal(self, line_num, @info_filename, "Desc-name missing for #{entry.identifier()}") if desc_name.nil?() || desc_name.value().empty?()
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
    elsif line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|uref|vref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
      tag = $1
      ref_type = $2
      given_ref = $3
      value = $4
      process_value(line_num, tag, ref_type, given_ref, value)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*Power-start\{(.*?)\}/ix
      # Power-start seen, so switch to power-block mode
      id = $1.strip()
      return HandlerResult::STACK_HANDLER, InfoFileHandlerPower.new(id, @info_filename, line_num, @local_refs, @refs, @pubs, @allow_only_vref)
    elsif line =~ /^\s*\*\*Dimensions-start\{(.*?)\}/ix
      # Dimensions-start seen, so switch to dimensions-block mode
      id = $1.strip()
      return HandlerResult::STACK_HANDLER, InfoFileHandlerDimensions.new(id, @info_filename, line_num, @local_refs, @refs, @pubs, @allow_only_vref)
    elsif line.strip().empty?() || line =~ /^\s*!/ix
        # ignore blank lines and commented out lines
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^\s*\*\*Options-start\{(.*?)\}/ix
      # Options-start seen, so switch to options-block mode
      id = $1.strip()
      return HandlerResult::STACK_HANDLER, InfoFileHandlerOptions.new(id, @info_filename, line_num, @local_refs, @refs, @pubs)
    else
      log_fatal(self, line_num, @info_filename, "Invalid line: #{line}")
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
          log_fatal(self, line_num, @info_filename, "vref refers to non-existent lref{#{lref}}")
          @fatal_error_seen = true
          return
        end
        unless reference.nil?()
          @local_refs_non_vref_count[lref] += 1 unless ref_type =~ /vref/i  # count any reference except a vref
          ref_array << reference if ref_type =~ /vref/i
          # If only vref is alowed but some other ref has been used, fail now
          if @allow_only_vref && (ref_type !~ /vref/i)
            log_fatal(self, line_num, @info_filename, "On line #{line_num} in #{@entry.identifier()}, disallowed reference type #{ref_type} has been used.")
            @fatal_error_seen = true
          end
        end
      }
    end
    if @permitted_tags_uc.include?(tag.upcase())
      # If the instance variable already exists then something has been defined twice
      instance_variable_name = EntriesCollection.tag_to_instance_variable_name(tag)
      if @entry.instance_variable_defined?(instance_variable_name)
        raise("On line #{line_num} in #{@entry.identifier()}, tag #{tag} has been defined again.")
      else
        # TODO HERE
        # Set the appropriate instance variable to the value+reference(s) specified
        @entry.instance_variable_set(instance_variable_name, VariableWithReference.new(value, ref_array))
      end
    else
      log_fatal(self, line_num, @info_filename, "In #{@entry.identifier()}, unknown tag [#{tag}] has been used. permitted=#{@permitted_tags_uc}")
      @fatal_error_seen = true
    end
  end

  def process_local_reference_definition(line_num, id, ref_name)
    ref = @refs[ref_name]
    if ref.nil?()
      log_fatal(self, line_num, @info_filename, "lref{#{id}} of [#{ref_name}] not found")
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
      log_fatal(self, line_num, @info_filename, "Doc [#{doc_id}] not found")
      @fatal_error_seen = true
    elsif !@local_docs[doc_id].nil?()
      log_fatal(self, line_num, @info_filename, "Doc [#{doc_id}] repeated")
      @fatal_error_seen = true
    else
      # Skip documents that have no title: what could they possibly mean?
      if doc["title"].nil?()
        log_fatal(self, line_num, @info_filename, "Doc [#{doc_id}] has no title")
        @fatal_error_seen = true
      else
        entry = doc["title"] + ". "
        entry += doc["part-no"] unless doc["part-no"].nil?()
        @local_docs[doc_id] = entry
      end
    end
  end

  # Invoked to process an enclosed block that has now been completely parsed
  def process_sub_handler(sub_handler)
    if sub_handler.respond_to?(:text_block)
      @entry.add_text(sub_handler.text_block())
    elsif sub_handler.respond_to?(:power)
      # If a second power block is being added, report if the first has no label
      if (@power.size() == 1) and !@power[0].label_defined?()
        log_fatal(self, @power[0].line_num(), @info_filename, "Power block #{@power[0].identifier()} starting on line #{@power[0].line_num} has no label")
        @fatal_error_seen = true
      end
      # If any block after the first is being added, report if it does not have a label
      power = sub_handler.power()
      if !power.label_defined? and @power.size() > 1
        log_fatal(self, power.line_num(), @info_filename, "Power block #{power.identifier()} starting on line #{power.line_num} has no label, but needs one")
        @fatal_error_seen = true
      end
      @power << power
    elsif sub_handler.respond_to?(:dimensions)
      # If a second dimensions block is being added, report if the first has no label
      if (@dimensions.size() == 1) and !@dimensions[0].label_defined?()
        log_fatal(self, @dimensions[0].line_num(), @info_filename, "Dimensions block #{@dimensions[0].identifier()} starting on line #{@dimensions[0].line_num} has no label")
        @fatal_error_seen = true
      end
      # If any block after the first is being added, report if it does not have a label
      dimensions = sub_handler.dimensions()
      if !dimensions.label_defined?{} and @dimensions.size() > 1
        log_fatal(self, dimensions.line_num(), @info_filename, "Dimensions block #{dimensions.identifier()} starting on line #{dimensions.line_num} has no label, but needs one")
        @fatal_error_seen = true
      end
      @dimensions << dimensions
    elsif sub_handler.respond_to?(:options)
      @options << sub_handler.options()
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

  attr_accessor   :fatal_error_seen
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
              log_fatal(self, line_num, @info_filename, "vref refers to non-existent lref{#{lref}}")
              @fatal_error_seen = true
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

# Encapsulates an Entry
class Entry

  attr_reader :identifier
  attr_reader :line_num
  attr_reader :sys_class
  attr_reader :entry_type
  attr_reader :tags # TODO
  
  def initialize(identifier, type, sys_class, line_num, tags)
    @identifier = identifier
    @line_num = line_num
    @entry_type = type
    @sys_class = VariableWithReference.new(sys_class, nil)
    @tags = tags
    @docs = []
    @text_block = []
    @local_references = []
    @power_block = []
    @dimensions_block = []
    @options_block = []
  end

  def set_docs(docs)
    @docs = docs  # Intended to be an array
  end

  def set_local_references(refs)
    @local_references = refs # Intended to be an array
  end

  def set_power(power)
    @power_block = power  # Intended to be an array
  end

  def set_dimensions(dimensions)
    @dimensions_block = dimensions  # Intended to be an array
  end

  def set_options(options)
    @options_block = options  # Intended to be an array
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
    @tags.tag_array().each() {
      |value|
      instance_variable_name = EntriesCollection.tag_to_instance_variable_name(value.name())
      if self.instance_variable_defined?(instance_variable_name)
        # Use tag name (i.e. value.name()) for the "name" and represent the value as an array with the first element as the actual value
        # and any further elements representing references.
        h[value.name()] = self.instance_variable_get(instance_variable_name).as_array()
      end
    }

    # If @docs is present and not empty, try representing it
    h["docs"] = @docs unless @docs.nil?() || @docs.empty?()

    # If @local_references is present and not empty, try representing it
    h["local_references"] = @local_references unless @local_references.nil?() || @local_references.empty?()

    # If @text_block is present and not empty, try representing it
    h["text_block"] = @text_block unless @text_block.nil?() || @text_block.empty?()

    # If @power_block is present, try representing it
    h["power_block"] = @power_block unless @power_block.nil?() || @power_block.empty?()

    # If @dimensions_block is present, try representing it
    h["dimensions_block"] = @dimensions_block unless @dimensions_block.nil?() || @dimensions_block.empty?()

    # If @options_block is present, try representing it
    unless @options_block.nil?() || @options_block.empty?()
      options_array = []
      @options_block.each() {
        |opt_block|
        options_array << opt_block.as_array()
      }
      h["options_block"] = options_array
    end

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

  def add_entry(entry, line_num, filename)
    if @entries.has_key?(entry.identifier())
      log_fatal(self, line_num, filename, "Duplicate entry #{entry.identifier()}, original declared on line #{@entries[entry.identifier()].line_num()}")
      return nil
    else
      @entries[entry.identifier()] = entry
      return entry
    end
  end

  def [](identifier)
    @entries[identifier]
  end

  def each()
    @entries.keys().sort().each() {
      |id|
      yield(id, @entries[id])
    }
  end

  def to_yaml()
    @entries.to_yaml()
  end

  # Reads an .info file and processes it.
  #
  # info_filename: the filepath of the .info file
  # type_expected: type of device: decvt etc.
  # tags: a DataTags object (which represent each permitted tag)
  # refs: references (from refs.info)
  # refs: publications (from pubs.info)
  def EntriesCollection.create_from_info_file(info_filename, type_expected, tags, refs, pubs)
    fatal_error_seen = false
    line_num = 0
    devices = EntriesCollection.new()
    ## TODO total_uses = 0   # local uses of unverified refs
    within_text_block = false

    handlers = [ InfoFileHandlerOuter.new(tags, info_filename, type_expected, refs, pubs, devices) ]
    IO.foreach(info_filename) {
      |line|
      current_handler = handlers[-1]
      line_num += 1
      line = line.chomp().strip()
      result, extra = current_handler.process_line(line, line_num)
      fatal_error_seen = true if current_handler.fatal_error_seen()
      case result
      when HandlerResult::IMMEDIATE_STOP
        if current_handler.respond_to?(:stop_processing_is_valid)
          fatal_error_seen = true if current_handler.fatal_error_seen()
          break
        else
          raise("Saw IMMEDIATE_STOP inside an entry: line #{line_num}: [#{line}]")
        end
      when HandlerResult::CONTINUE
        log_debug(self, line_num, info_filename, "saw CONTINUE for: [#{line}]")
      when HandlerResult::STACK_HANDLER
        # Use replacement handler
        handlers << extra
        current_handler = extra
        log_debug(self, line_num, info_filename, "processed result: STACK_HANDLER for: [#{line}]")
      when HandlerResult::COMPLETED
        fatal_error_seen = true if current_handler.fatal_error_seen()
        handlers.pop()
        handlers[-1].process_sub_handler(current_handler)  # TODO actually this should be passed to the handler that caused it to be invoked
        log_debug(self, line_num, info_filename, "saw  result: COMPLETED for: [#{line}]")
      else
        raise("saw UNKNOWN result: #{result} for line #{line_num}: [#{line}]")
      end
    }

    # Here the end of the file has been reached or **stop-processing was seen.
    # Either way, there should be one handler on the stack and it should be the Outer one
    # (which is the only one that allows **stop-processing).
    if (handlers.size() > 1) or !handlers[0].respond_to?(:stop_processing_is_valid)
      log_fatal(self, line_num, info_filename, "Finished processing mid-entry")
      fatal_error_seen = true
    elsif handlers[0].fatal_error_seen()
      fatal_error_seen = true           # Catch the Outer handler's fatal error if one has been seen
    end

    raise("FATAL ERROR: Stopping because of one or more above fatal errors") if fatal_error_seen

    return devices
  end

end
