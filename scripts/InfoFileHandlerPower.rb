#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "VariableWithReference.rb"

#+
# The InfoFileHandlerPower class handles a block of declarations representing power information.
#-
class InfoFileHandlerPower

  attr_accessor   :fatal_error_seen

  attr_reader     :entry
  attr_reader     :power

  def initialize(id, info_filename, line_num, local_refs, refs, pubs, allow_only_vref)
    @fatal_error_seen = false
    @id = id
    @info_filename = info_filename
    @local_refs = local_refs
    @local_refs_non_vref_count = {}
    @refs = refs
    @pubs = pubs
    @tags = DataTags.new('scripts/power-tags.yaml', 'systems', 'decvt')  ## TODO hard-coded filename for now
    @permitted_tags_uc = @tags.tags().map(&:upcase)
    @power = Power.new(@id, line_num, @tags.tags())
    @allow_only_vref = allow_only_vref
  end

  def process_line(line, line_num)
    if line =~ /\*\*Power-end\{(.*)\}/ix
      # e.g. **Power-end{VT100KBD}
      end_id = $1.strip()
      if end_id != @id
        log_fatal(self, line_num, @info_filename, "**Power-end\{#{end_id}\} does not match **Power-start\{#{@id}\}") if end_id != @id
        @fatal_error_seen = true
      end
      @local_refs.keys().each() {
        |k|
        ## TODO is this needed? total_uses += @local_refs_non_vref_count[k]
        ## TOOD count_text = "%3.3d" % @local_refs_non_vref_count[k]
      }
      return HandlerResult::COMPLETED, nil
    elsif line =~ /^ \*\* ([^*:\s]+) \s* (?: \*\* (htref|uref|vref) \{ ([^}]+) \})? \s* : \s* (.*) \s* $/ix
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
          ## TODO @local_refs_non_vref_count[lref] += 1 unless ref_type =~ /vref/i  # count any reference except a vref
          ref_array << reference if ref_type =~ /vref/i
          # If only vref is alowed but some other ref has been used, fail now
          if @allow_only_vref && (ref_type !~ /vref/i)
            log_fatal(self, line_num, @info_filename, "On line #{line_num} in #{@id}, disallowed reference type #{ref_type} has been used.")
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
        valid = if !@tags[tag].nil?()
                  @tags[tag].validate_value(value)
                else
                  true
                end
        if !valid
          log_fatal(self, line_num, @info_filename, "On line #{line_num} in Power{#{@id}} tag #{tag}, badly formatted or invalid data [#{value}].")
          @fatal_error_seen = true
        end
        # Set the appropriate instance variable to the value+reference(s) specified
        @power.instance_variable_set(instance_variable_name, VariableWithReference.new(value, ref_array))
      end
    else
      log_fatal(self, line_num, @info_filename, "In #{@id}, unknown tag [#{tag}] has been used. permitted=#{@permitted_tags_uc}")
      @fatal_error_seen = true
    end
  end

  # No sub handlers are allowed: i.e. no new type can start inside this one
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

  # This function will be called when to_yaml() encounters an object of type Power.
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

    coder.represent_map(nil, h)
  end

end
