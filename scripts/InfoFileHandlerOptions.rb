#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "VariableWithReference.rb"

module OptionPart
  TITLE = 0
  TEXT = 1
end

#+
# The InfoFileHandlerOptions class handles a block of declarations representing options information.
#-
class InfoFileHandlerOptions

  attr_reader     :entry
  attr_reader     :fatal_error_seen
  attr_reader     :options

  def initialize(id, info_filename, line_num, local_refs, refs, pubs)
    @fatal_error_seen = false
    @id = id
    @info_filename = info_filename
    @local_refs = local_refs
    @local_refs_non_vref_count = {}
    @refs = refs
    @pubs = pubs
    @options = Options.new(@id, line_num)
    log_debug(self, line_num, @info_filename, "Options-start\{#{@id}\}")
  end

  def process_line(line, line_num)
    if line =~ /\*\*Options-end\{(.*)\}/ix
      # e.g. **Options-end{DEC4600}
      end_id = $1.strip()
      if end_id != @id
        log_fatal(self, line_num, @info_filename, "**Options-end\{#{end_id}\} does not match **Options-start\{#{@id}\}")
        @fatal_error_seen = true
      end
      log_debug(self, line_num, @info_filename, "Options-end\{#{@id}\}")
      return HandlerResult::COMPLETED, nil
    elsif line =~ /^ \s* \*\*Option\s* (?: \*\*vref \{ ([^}]+) \})? \s* : \s*(.*)\s*$/ix
      given_ref = $1
      option_text = $2.strip()
      process_option(line_num, option_text, given_ref)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^ \s* \*\*Option-title\s*:\s*(.*)\s*$/ix
      title = $1.strip()
      @options.add_title(title)
      return HandlerResult::CONTINUE, nil
    elsif line.strip().empty?() || line =~ /^\s*!/ix
        # ignore blank lines and commented out lines
      return HandlerResult::CONTINUE, nil
    else
      log_fatal(self, line_num, @info_filename, "Invalid line: #{line}")
      @fatal_error_seen = true
      return HandlerResult::CONTINUE, nil
    end
  end

  # Process the value part of a single line of the form
  #
  # **Option: {class:name}{text}
  #
  # e.g.
  #
  # {storage:RF35}{852MB DDSI Disk}
  #
  # Currently ignore the first part and use the second part as a text string
  #
  def process_option(line_num, value, given_ref)
    unless given_ref.nil?()
      ref_array = []
      reference = nil
      given_ref.strip().split(",").each() {
        |lref|
        reference = @local_refs[lref]
        if reference.nil?()
          log_fatal(self, line_num, @info_filename, "vref refers to non-existent lref{#{lref}}")
          @fatal_error_seen = true
          return
        end
        unless reference.nil?()
          ## TODO @local_refs_non_vref_count[lref] += 1 unless ref_type =~ /vref/i  # count any reference except a vref
          ref_array << reference
        end
      }
    end
    if value =~ /^\{(.*?)\}\s*\{(.*?)\}$/ix
      @options.add_option($1.strip(), $2.strip(), ref_array)
    elsif value =~ /^\{(.*?)\}$/ix
      @options.add_option($1.strip(), "", ref_array)
    else
      raise("Badly formed option on line #{line_num} in #{@info_filename}")
    end
  end

  # No sub handlers are allowed: i.e. no new type can start inside this one
  def process_sub_handler(sub_handler)
    raise("No sub block expected but handed #{sub_handler.class.name()}")
  end
end

# Encapsulates an Options block
class Options

  attr_reader     :identifier
  attr_reader     :line_num

  def initialize(identifier, line_num)
    @identifier = identifier
    @line_num = line_num
    @options = []
  end

  def add_option(device, text, ref_array)
    if !ref_array.nil?() && !ref_array.empty?()
      @options << [OptionPart::TEXT, [device, text, ref_array].flatten()]
    else
      @options << [OptionPart::TEXT, [device, text]]
    end
  end

  def add_title(title)
    @options << [OptionPart::TITLE, title]
  end

  def as_array
    a = []
    @options.each() {
      |opt|
      if opt[0] == OptionPart::TEXT
        a << ['option_text', opt[1]]
      elsif opt[0] == OptionPart::TITLE
        a << ['option_title', opt[1]]
      else
        raise("Error parsing options")
      end
    }
    return a
  end

end
