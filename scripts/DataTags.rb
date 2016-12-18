#!/usr/bin/ruby -w

require 'yaml'

# A Tag represents almost that a YAML tag entry contains.
# name: the name of the tag (e.g. "FCS-date")
# display_text: text to display to the user describing the tag (e.g. "FCS date")
# category: the display category (e.g. 'summary', 'io')
# required: true if the entry should be displayed even if no value is known
class Tag
  attr_accessor :category
  attr_accessor :display_text
  attr_accessor :name
  attr_accessor :required

  # name - name of this tag
  # array[0] - display text
  # array[1] - applicable area (vax, alpha, systems, all)
  # array[2] - category (summary, io)
  # array[3] - required
  def initialize(name, properties)
    @name = name
    @display_text = if properties.size() >= 1
                      properties[0]
                    else
                      nil
                    end
    @category = if properties.size() >= 3
                  properties[2]
                else
                  nil
                end
    @required = if properties.size() >= 4
                  properties[3] =~/required/i
                else
                  false
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
    # data is [ {tag => [display-text,type,category,required]]

    @tags = {}
    data.each() {
      |d|
      # d is a single entry hash: { name => properties array }
      name = d.first()[0]
      properties = d.first()[1]
      applicability = properties[1].downcase()
      next unless applicability == 'all' || applicability == type || applicability == sub_type
      @tags[name] = Tag.new(name, properties)
    }

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
end
