#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require_relative "DataPubTxt.rb"

require "yaml"

info = ARGV.shift()

# Load the refs.info
pubs = Publications.create_from_info_file(info)

# Output in form suitable for info file
pubs.each() {
  |key|
  pub = pubs[key]
  next if pub.identifier().nil?() || pub.identifier().empty?()
  id = "{" + pub.identifier() + "}"
  if id.length() < 40
    id = '%-40.40s' % id
  end
  puts("**document=doc" + id + "! #{pub.title()}")
}
