#!/usr/bin/ruby -w

# Used DataRefInfo.rb as a starting point.

# Currently silently ignores a duplicate entry.

# Reads a publications file (e.g. pubs.txt) and allows production of YAML for any entries.

# Publications.create_from_info_file(info_filename)
#  Builds a Pub object from a pubtxt file.
#  Publications is a collection of Pub objects, each of which represents a single publication entry.
#
# Publications.each()
#  Allows each contained ref object to be accessed in turn.
#
# Pub.encode_with(coder)
#  This is the function that is invoked when to_yaml() is called on a Pub object.
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

class Pub
  attr_accessor :author
  attr_accessor :confidential
  attr_accessor :date
  attr_accessor :electronic_format
  attr_accessor :fonds
  attr_accessor :format
  attr_accessor :isbn
  attr_accessor :location
  attr_accessor :notes
  attr_accessor :part_no
  attr_accessor :publisher
  attr_accessor :successor
  attr_accessor :supersedes
  attr_accessor :title
  attr_accessor :version
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
    @fonds = nil
    @version = nil
    @date = nil
    @notes = nil
    @confidential = nil
    @supersedes = nil
    @successor = nil
  end
  
##  def confidential(text)
##    @confidential = (text =~ /^yes$/ix)
##  end
  
  # This function will be called when to_yaml() encounters an object of type Pub.
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
    h["fonds"] = @fonds unless @fonds.nil?()
    h["version"] = @version unless @version.nil?()
    h["date"] = @date unless @date.nil?()
    h["notes"] = @notes unless @notes.nil?()
    h["confidential"] = @confidential unless @confidential.nil?()
    h["supersedes"] = @supersedes unless @supersedes.nil?()
    h["successor"] = @successor unless @successor.nil?()

    coder.represent_map(nil, h)
  end
end

class Publications

  DATA_REFERENCES_ID = "DataPublications"

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

  # Reads a refs.info file and produces returns a Publications object containing parsed data.
  def Publications.create_from_info_file(info_filename)
    line_num = 0
    current = nil
    ret = Publications.new()
    IO.foreach(info_filename) {
      |line|
      line_num += 1
      line = line.chomp().strip()
      
      if line.strip().empty?() || line =~ /^ \s* \#/ix
        # ignore blank lines and commented out lines
        next
      elsif line =~ /^\s*\*\*Stop-processing\s*$/
        # Stop if a line with just "**Stop-processing" is seen.
        break
      elsif line =~ /start-publication \s+ (.*)/ix # TODO - better limits on names
        id = $1.strip()
##        raise("Duplicate publication [#{id}] read in #{info_filename} at line #{line_num}: #{line} (originally #{ret[id].line_num()})") if ret[id] != nil
        current = Pub.new(id, line_num)
        next
      elsif line =~ /end-publication \s* .*/ix
        # TODO - check closing the right one, then add to pile
        ret.add_ref(current)
        next
      elsif current == nil
        # TODO - line outside of reference?
        next
      end
      
      # Here process a line within a ref
      if line =~ /^ (.*?) \s* = \s* (.*) $/ix
        tag = $1
        value = $2
        case tag
        when /^title$/ix         then current.title = value
        when /^part-no$/ix
          current.part_no = value
          if current.part_no[-1] == "}"
            raise("part-no ends in '}': in #{info_filename} at line #{line_num}: #{line}")
          end
        when /^publisher$/ix     then current.publisher = value
        when /^fonds$/ix         then current.fonds = value
        when /^isbn$/ix          then current.isbn = value
        when /^authors?$/ix      then current.author = value    # Note: deliberately allow either "author = " or "authors = "
        when /^version$/ix       then current.version = value
        when /^date$/ix          then current.date = value
        when /^notes$/ix         then current.notes = value
        when /^confidential$/ix  then current.confidential = value
        when /^supersedes$/ix    then current.supersedes = value
        when /^successor$/ix     then current.successor = value

        when /^Pub-electronic$/ix   then current.electronic_format = value
        when /^Pub-format$/ix       then current.format = value # TODO ?
        when /^Pub-location$/ix     then current.location = value
        when /^Pub-hardcopy$/ix     then ; # TODO yes/no ?
        when /^Pub-processed/ix     then ; # TODO yes/no ?
        # else raise("Bad line read in #{info_filename} at line #{line_num}: #{line}")
        else $stderr.puts("Bad line read in #{info_filename} at line #{line_num}: #{line}")
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
