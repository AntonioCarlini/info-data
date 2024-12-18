#!/usr/bin/ruby -w

require 'yaml'


# Function to simplify logging of fatal errors
def log_fatal(this, line_num, filename, text)
  $stderr.puts("FATAL ERROR from #{this.class().name()}: line #{line_num} in #{filename}: #{text}")
  this.fatal_error_seen = true
end

# Monkey patch the String class to perform some simple integer checks.
class String

  # True if the string is a decimal integer (ignoring leading and trailing whitespace)
  def is_positive_decimal_integer?
    return false unless self =~ /^\s*[0-9]+\s*/
    return self.to_i().to_s() == self.strip()
  end
end

# A Validator will be called for those tags that specify a validation method
class Validator

  attr_accessor :validator
  attr_accessor :fatal_error_seen
  
  def initialize(validation_parameters)

    @fatal_error_seen = false
    @parameters = nil
    
    style = validation_parameters[0]
    
    case style
    when style.nil?() || style.empty?()
      @validator = method(:always_valid)
    when "yn"
      @validator = method(:enforce_yes_no)
    when "date"
      @validator = method(:enforce_date)
    when "int"
      @validator = method(:enforce_positive_decimal_integer)
    when "int-range"
      @validator = method(:enforce_integer_range)
    when "float"
      @validator = method(:enforce_simple_fp)
    when "regexp"
      @validator = method(:enforce_regexp)
    when "physical-unit"
      @validator = method(:enforce_physical_unit)
      @parameters = validation_parameters.drop(1)
    else
      @validator = method(:always_valid)
      $stderr.puts("Saw validation_parameters=[#{validation_parameters}]   [0]=[#{validation_parameters[0]}] [0][0]=[#{validation_parameters[0][0]}] [0][1]=[#{validation_parameters[0][1]}] [1]=[#{validation_parameters[1]}]  class=#{validation_parameters.class} class[0]=#{validation_parameters[0].class} ")
      @fatal_error_seen = true
    end
  end

  # Text is always valid, i.e. no actual check is performed
  def always_valid(text)
    $stderr.puts("Invoked enforcer always_valid on [#{text}]")
    return true
  end

  # Check that the supplied text matches Yes or No or Y or N
  def enforce_yes_no(text)
    return text =~ /^(y|n|yes|no)$/ix
  end

  # Verify that the text supplied matches YYYY and lies in the range [1957, 2100]
  def check_year(year_text)
    return false if year_text !~ /^[0-9]{4}$/
    year = year_text.to_i()
    # Verify that the year is acceptable
    return (year >= 1957) && (year < 2100)
  end

  # Verify that the text supplied matches MM (i.e. 01-12)
  def check_month(month_text)
    return false if month_text !~ /^[0-9]{2}$/
    month = month_text.to_i()
    # Verify that the month is acceptable
    return (month >= 1) && (month <= 12)
  end

  # Verify that the text supplied matches DD (i.e. 01-31)
  def check_day(day_text)
    return false if day_text !~ /^[0-9]{2}$/
    day = day_text.to_i()
    # Verify that the month is acceptable
    return (day >= 1) && (day <= 31)
  end

  # Check that the supplied text matches a date in the form YYYY[-MM[-DD]].
  def enforce_date(date)
    fields = date.split("-")
    case fields.length()
    when 1
      # If only year supplied, ensure that it has four digits
      return check_year(fields[0])
    when 2
      return false if ! check_year(fields[0])
      return false if ! check_month(fields[1])
      return true
    when 3
      return false if ! check_year(fields[0])
      return false if ! check_month(fields[1])
      return false if ! check_day(fields[2])
      # TODO here check that the day is valid for the month i.e. disallow YYYY-02-31
      return true
    else
      return false
    end
  end

  # Check that the supplied text matches a decimal integer
  def enforce_positive_decimal_integer(text)
    return text.is_positive_decimal_integer?()
  end

  # Check that the supplied text matches a decimal integer range
  # i.e. "N - M", where N and M are positive decimal integers
  def enforce_integer_range(text)
    return text =~ /^\s*\d+\s*-\s*\d+\s*$/
  end

  # Check that the supplied text matches a simple floating point value
  # That is AAAA.BBBB where there may be 0 or more As, 0 or more Bs and
  # the decimal point is optional unless at least one B is present
  def enforce_simple_fp(text)
    return text =~ /^\d*?(\.\d+?)?$/
  end

  # Check that the supplied text matches a simple floating point value
  # followed by any one of the array of parameters.
  # For example this could match "2.0 A" or "2.0 mA"
  def enforce_physical_unit(text)
    units = @parameters.compact().join("|")
    r = Regexp.quote("#{units}")
    modifiers = "approx|average|idle|maximum|nominal|operating|peak|printing|seeking|typical"
    return text =~ /^\s*\d*?(\.\d+?)?\s*#{units}\s*(:(#{modifiers}))?$/
  end

  # Invokes the chosen validator and returns its result
  def validate_value(value)
    return @validator.call(value)
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
        if properties[4] !~ /^required|optional$/ix
          $stderr.puts("FATAL ERROR: Bad always_display seen for #{name}: #{properties[4]}")
          @fatal_error_seen = true
        end
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
      ## $stderr.puts("saw prop=[#{properties}]  p[5]=[#{properties[5]}]")
      @validator = Validator.new(properties[5])
      if @validator.fatal_error_seen()
        $stderr.puts("FATAL ERROR: Bad validator seen for #{name}: #{properties[5]}")
        @fatal_error_seen = true
      end
    end
  end
  
  def validate_value(value)
    if @validate && !@validator.nil?()
      return @validator.validate_value(value)
    else
      return true
    end
  end
  
end

class DataTags
  
  attr_reader :tag_array
  
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

  # Return an array of the tag names
  def tags()
    tags = []
    @tags.each() { |k,v| tags << k }
    return tags
  end

  # Return an array of the tag names in uppercase
  def tags_uc()
    tags = []
    @tags.each() { |k,v| tags << k.upcase() }
    return tags
  end

  # Yield for each tag
  def each_in_order()
    @tag_array.each() { |tag| yield tag }
  end
end
