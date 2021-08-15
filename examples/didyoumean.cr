#!/usr/bin/env ruby
require "../src/optimist"

opts = Optimist.options do
  opt :cone, "Ice cream cone"
  opt :zippy, "It zips"
  opt :zapzy, "It zapz"
  opt :big_bug, "Madagascar cockroach"
end

opts.each { |k,v| p [k, v.value, v.given?] }

