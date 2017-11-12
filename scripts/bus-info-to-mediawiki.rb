#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataTags.rb"

#+
# This script turns a bus.info file into a mediawiki page with one table for each bus.

bus_type = ARGV.shift().downcase()    # This could be a specific bus or "all"
bus_info = ARGV.shift()             # This is the bus.info file

bus_titles = {
  "AQUARIUS" => "VAX 9000",
  "COMET" => "VAX-11/750",
  "DECNIS" => "DECnis",
  "EISA" => "EISA",
  "FIREFOX" => "VAXstation 35x0/38x0",
  "LSB" => "LaserBUS",
  "LYNX" => "VAX 82x0/83x0",
  "NEBULA" => "VAX-11/725, VAX-11/730",
  "OMEGA" => "VAX 4000",
  "PCI" => "PCI",
  "POLARSTAR" => "VAX 88x0",
  "QBUS" => "QBUS",
  "RAWHIDE" => "AlphaServer 4100",
  "COBRA" => "DEC 4000",
  "SABLE" => "AlphaServer 2x00",
  "TURBO" => "TURBOchannel",
  "UNIBUS" => "UNIBUS",
  "VAXBI" => "VAXBI",
  "VENUS" => "VAX 86x0",
  "XMI" => "XMI"
}
# The data_by_bus is a hash with "bus" as its key.
# Each value is a hash with "module" as its key and "entry" as its value.
data_by_bus = Hash.new() { |h, k| h[k] = Hash.new() }

# Read the bus.info file line by line.
# Each non-blank line should be repeated entries of the form
#    A = B.
# The spaces before and after the equals are optional.
# B may consist of a leading double-quote, in which case it ends on the trailing double quote. Otherwise it ends at the next space.
#

line_num = 0

IO.foreach(bus_info) {
  |line|
  line_num += 1
  line = line.chomp().strip()

  if line.nil?() || line.strip().empty?() || line =~ /^ !/ix
    next        # ignore blank lines and commented out lines
  elsif line =~ /^\s*\*\*Stop-processing\s*$/i
    break       # Stop if a line with just "**Stop-processing" is seen.
  end
  entry = Hash.new()

##  puts("Processing line [#{line}]")
  # Repeatedly look for A, B pairs, until the line is empty.
  loop do
##    puts("Examining [#{line}]")

    break if line.nil?() || line.empty?() || line =~ /^ !/ix
    # The A ends at the first "=".
    # The B ends at the next space or, if its first non-whitespace char is a double quote, then it ends at the next double quote
    a, rest = line.split("=", 2)
    a = a.strip()
    rest = rest.strip()
    b = nil
##    puts("Finding B in [#{rest}]")
    if rest =~ /^"([^"]+)"(.*)/
      b = $1
      line = $2
    else
      b, line = rest.split(/\s+/, 2)
    end
##    puts("Found [#{a}]=[#{b}] LEAVING [#{line}]")
    entry[a] = b
  end
##  puts("FINISHED processing line")
##  exit if line_num > 2

  # At this point 'entry' is a hash of A => B values.
  # One of those must be 'bus' otherwise something is wrong.
  # Another one must be "module", otherwise what have we created?
  bus = entry["bus"]
  mod = entry["module"]
  if bus.nil?()
    $stderr.puts("At line #{line_num} at 'bus' is missing: #{entry.inspect()}")
    next
  end

  # TURBO(channel), PCI and EISA cards have a name instead of a module
  mod = entry["name"] if bus.downcase =~ /^TURBO$|^PCI$|^EISA$/i
  if mod.nil?()
    $stderr.puts("At line #{line_num} at least one of 'module' or 'name' is missing: #{entry.inspect()}")
    next
  end

  # Store the entry in the hash for the appropriate bus
  data_by_bus[bus.downcase()][mod] = entry
}

##puts("Processed everything")

data_by_bus.keys().sort().each() {
  |bus|
  next unless bus_type == "all" || bus_type == bus

  entries = data_by_bus[bus]

  # Temporary: skip those busses for which there are many, many entries to avoid producing a page that is far too long.
  if entries.size() > 50
    $stderr.puts("Skipping #{bus}: too many entries (#{entries.size()})")
    next
  end

  no_module = (bus =~ /^TURBO$|^PCI$|^EISA$/i)
  puts("== #{bus_titles[bus.upcase()]} Modules ==")
  puts('{| class="wikitable"')
  puts('! style="padding: 0 1em 0;" | Module') unless no_module
  puts('! style="padding: 0 1em 0;" | Name')
  puts('! style="padding: 0 1em 0;" | Description')

  entries.keys().sort().each() {
    |mod|
    entry = entries[mod]
    puts("|-")
    puts(%Q{| style="padding: 0 1em 0;" | #{mod} }) unless no_module
    puts(%Q{| style="padding: 0 1em 0;" | #{entry['name']}})
    puts(%Q{| style="padding: 0 1em 0;" | #{entry['desc']}})
  }
  puts("|}\n\n")
}
