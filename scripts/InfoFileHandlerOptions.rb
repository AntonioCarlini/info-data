#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "VariableWithReference.rb"

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
    elsif line =~ /^ \s* \*\*Option\s*:\s*(.*)\s*$/ix
      option_text = $1.strip()
      #TODO process_option(option_text)
      return HandlerResult::CONTINUE, nil
    elsif line =~ /^ \s* \*\*Option-title\s*:\s*(.*)\s*$/ix
      title = $1.strip()
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

  # Currently unused
  def process_option(line_num, tag, ref_type, given_ref, value)
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
  end

  # This function will be called when to_yaml() encounters an object of type Options.
  # It encodes its data as though it were a hash of:
  #   { tag e.g. "FRS-date" => [value, ref#1, ref#2] }
  #
  def encode_with(coder)
    h = {}
    ## TODO currently no data present
    coder.represent_map(nil, h)
  end
end
