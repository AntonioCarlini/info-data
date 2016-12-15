#!/usr/bin/ruby -w

# Copied from vintage ../vintage-2012/software/DataRef.rb.

# Reads a references file (e.g. refs.info) and allows production of YAML for any entries.

# References.create_from_info_file(info_filename)
#  Builds a References object from a refs.info file.
#  References is a collection of Ref objects, each of which represents a single reference entry.
#
# References.each()
#  Allows each contained ref object to be accessed in turn.
#
# Ref.encode_with(coder)
#  This is the function that is invoked when to_yaml() is called on a Ref object.
#
# Meanings of the fields:
#
# identifier: This is the key used to access the item and will often match the part number. It is always present.
# title: Title as printed on the document
# part-no: A part number e.g. AA-2573P-TCT1
# electronic-format: The format, if the document is electronic, e.g. PDF, MEM, TXT, BOOKREADER, LN3, PS, HTML
# format: UNKNOWN
# location: UNKNOWN
# confidential
# isbn: ISBN
# author: Author names
# publisher: Publisher (but not used for DEC manuals)

class Ref
  attr_accessor :author
  attr_accessor :electronic_format
  attr_accessor :format
  attr_accessor :isbn
  attr_accessor :location
  attr_accessor :part_no
  attr_accessor :publisher
  attr_accessor :title
  attr_reader   :identifier
  attr_reader   :line_num
  
  def initialize(identifier, line_num)
    @identifier = identifier
    @line_num = line_num
    @title = nil
    @part_no = nil
    @electronic_format = nil
    @format = nil
    @location = nil
    @confidential = false
    @isbn = nil
    @author = nil
    @publisher = nil
  end
  
  def confidential(text)
    @confidential = (text =~ /^yes$/ix)
  end
  
  # This function will be called when to_yaml() encounters an object of type Ref.
  # It encodes is data as though it were a hash of:
  #   { identifier => {hash of relevant member variables} }
  #
  def encode_with(coder)
    h = {}
    h["title"] = @title  unless @title.nil?()
    h["part-no"] = @part_no unless @part_no.nil?()
    h["electronic-format"] = @electronic_format unless @electronic_format.nil?()
    h["format"] = format unless @format.nil?()
    h["location"] = @location unless @location.nil?()
    h["confidential"] = @confidential ? 'Yes' : 'No'
    h["isbn"] = @isbn unless @isbn.nil?()
    h["author"] = @author unless @author.nil?()
    h["publisher"] = @publisher unless @publisher.nil?()

    coder.represent_map(nil, h)
  end
end

class References

  DATA_REFERENCES_ID = "DataReferences"

  def initialize
    @refs = {}
  end

  def add_ref(ref)
    @refs[ref.identifier()] = ref
  end
  
  def num_refs()
    @refs.size()
  end
  
  def [](identifier)
    @refs[identifier]
  end
  
  def each()
    @refs.keys().sort().each() {
      |id|
      yield id
    }
  end

  def to_yaml()
    @refs.to_yaml()
  end

  # Reads a refs.info file and produces returns a References object containing parsed data.
  def References.create_from_info_file(info_filename)
    line_num = 0
    current = nil
    ret = References.new()
    IO.foreach(info_filename) {
      |line|
      line_num += 1
      line = line.chomp().strip()
      
      if line.strip().empty?() || line =~ /^ !/ix
        # ignore blank lines and commented out lines
        next
      elsif line =~ /^\s*\*\*Stop-processing\s*$/
        # Stop if a line with just "**Stop-processing" is seen.
        break
      elsif line =~ /\*\*Start-ref\{(.*)\}/ix # TODO - better limits on names
        id = $1.strip()
        raise("Duplicate reference [#{id}] read in #{info_filename} at line #{line_num}: #{line} (originally #{ret[id].line_num()})") if ret[id] != nil
        current = Ref.new(id, line_num)
        next
      elsif line =~ /\*\*End-ref\{.*\}/ix
        # TODO - check closing the right one, then add to pile
        ret.add_ref(current)
        next
      elsif line =~ / \s* \! /ix
        # skip comment line
        next
      elsif current == nil
        # TODO - line outside of reference?
        next
      end
      
      # Here process a line within a ref
      if line =~ /^ \*\* (.*?) : \s* (.*) $/ix
        tag = $1
        value = $2
        case tag
        when /^Ref-text$/ix         then current.title = value
        when /^Ref-partno$/ix       then current.part_no = value
        when /^Ref-electronic$/ix   then current.electronic_format = value
        when /^Ref-format$/ix       then current.format = value # TODO ?
        when /^Ref-location$/ix     then current.location = value
        when /^Ref-confidential$/ix then ; # TODO current.confidential = value
        when /^Ref-ISBN$/ix         then current.isbn = value
        when /^Ref-author$/ix       then current.author = value
        when /^Ref-publisher$/ix    then current.publisher = value
        when /^Ref-hardcopy$/ix     then ; # TODO yes/no ?
        when /^Ref-processed/ix     then ; # TODO yes/no ?
        else raise("Bad line read in #{info_filename} at line #{line_num}: #{line}")
        end
      elsif line.strip().empty?()
        raise("Muffed empty line check")
      elsif line =~ /^\s*!/
        raise("Muffed comment line check")
      else
        # TODO did not recognise line
        raise("unrecognised line [#{line}]")
      end
    }

    return ret
  end

end
