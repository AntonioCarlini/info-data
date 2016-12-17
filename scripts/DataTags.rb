#!/usr/bin/ruby -w

require 'yaml'

class DataTags
  
  # tags_yaml_file
  # type: systems, comms
  # sub_type: vax, alpha etc.
  def initialize(tags_yaml_file, type, sub_type)
    # Load the references YAML information
    @tags = YAML.load_file(tags_yaml_file)
    # @tags is [ {tag => [display-text,type,category,required]]

    # Discard all that do not match the type or sub-type (or 'all')
    @tags = @tags.keep_if() { |h| h.first[1][1].downcase() == 'all' || h.first[1][1].downcase() == sub_type || h.first[1][1].downcase() == type }

  end
  
  # Return an array of the tags
  def tags()
    tags = []
    @tags.each() { |h| tags << h.first[0] }
    return tags
  end

  # Return an array of the tags
  def tags_uc()
    tags = []
    @tags.each() { |h| tags << h.first[0].upcase() }
    return tags
  end
end
