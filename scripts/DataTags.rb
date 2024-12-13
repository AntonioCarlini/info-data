#!/usr/bin/ruby -w

require 'yaml'


# Function to simplify logging of fatal errors
def log_fatal(this, line_num, filename, text)
  $stderr.puts("FATAL ERROR from #{this.class().name()}: line #{line_num} in #{filename}: #{text}")
  this.fatal_error_seen = true
end


# A Validator will be called for 

class Validator

  attr_accessor :validator
  attr_accessor :fatal_error_seen
  
  def initialize(validation_parameters)

    @fatal_error_seen = false
    
    style = validation_parameters[0]
    
    case style
    when "yn"
      @validator = method(:enforce_yes_no)
    when "date"
      @validator = method(:enforce_date)
    when "regexp"
      @validator = method(:enforce_regexp)
    else
      @fatal_error_seen = true
    end
  end

  def enforce_yes_no(text)
    $stderr.puts("Invoked enforcer YN on [#{text}]")
    return text =~ /^(y|n|yes|no)$/ix
  end

end


# A Tag represents almost what a YAML tag entry contains.
# name: the name of the tag (e.g. "FCS-date")
# display_text: text to display to the user describing the tag (e.g. "FCS date")
# category: the display category (e.g. 'summary', 'io')
# required: true if the entry should be displayed even if no value is known
class Tag
  attr_accessor :always_display
  attr_accessor :category
  attr_accessor :display_text
  attr_accessor :explanatory_text
  attr_accessor :fatal_error_seen
  attr_accessor :name
  attr_accessor :validate
  attr_accessor :validation_method

  # name - name of this tag
  # array[0] - display text
  # array[1] - explanatory text
  # array[2] - applicable area (vax, alpha, systems, all)
  # array[3] - category (summary, io)
  # array[4] - always_display
  # array[5] - validation information
  def initialize(name, properties)
    @name = name
    @fatal_error_seen = false
    @display_text =
      if properties.size() >= 1
        properties[0]
      else
        nil
      end
    @explanatory_text =
      if properties.size() >= 2
        properties[1]
      else
        nil
      end
    @category =
      if properties.size() >= 4
        properties[3]
      else
        nil
      end
    @always_display = 
      if properties.size() >= 5
        properties[4] =~/required/i
      else
        false
      end
    @validate = 
      if properties.size() >= 6
        true
      else
        false
      end
    if @validate
      @validator = Validator.new(properties[5])
      if @validator.fatal_error_seen()
        $stderr.puts("FATAL ERROR: Bad validator seen for #{name}: #{properties[5]}")
        @fatal_error_seen = true
      end
    end
  end
  
end

class DataTags
  
  # tags_yaml_file
  # type: systems, comms
  # sub_type: vax, alpha etc.
  def initialize(tags_yaml_file, type, sub_type)
    # Load the references YAML information
    data = YAML.load_file(tags_yaml_file)
    # data is [ {tag => [display-text,explanatory-text,applicable-to,category,required,validator]]

    @tags = {}
    @tag_array = []
    fatal_error_seen = false

    data.each() {
      |d|
      # d is a single entry hash: { name => properties array }
      name = d.first()[0]
      properties = d.first()[1]
      applicability = properties[2]
      if applicability.respond_to?(:map)
        applicability.map(&:downcase)
      else
        applicability.downcase()
      end
      next unless applicability.include?('all') || applicability.include?(type) || applicability.include?(sub_type)
      tag = Tag.new(name, properties)
      @tags[name] = tag
      @tag_array << tag
      if tag.fatal_error_seen()
        $stderr.puts("FATAL ERROR: Invalid validation options for tag #{name}")
        fatal_error_seen = true
      end
    }

    if fatal_error_seen
      raise("Aborting processing of #{tags_yaml_file} because of above fatal errors")
    end
  end
  
  # Return a specified Tag
  def [](name)
    return @tags[name]
  end

  # Return an array of the tags
  def tags()
    tags = []
    @tags.each() { |k,v| tags << k }
    return tags
  end

  # Return an array of the tags
  def tags_uc()
    tags = []
    @tags.each() { |k,v| tags << k.upcase() }
    return tags
  end

  def each_in_order()
    @tag_array.each() { |tag| yield tag }
  end
end
