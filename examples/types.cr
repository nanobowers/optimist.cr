#!/usr/bin/env ruby
require "../src/optimist"

opts = Optimist.options do
  opt :xx, "x opt", cls: Optimist::StringOpt
  opt :yy, "y opt", cls: Optimist::Float64Opt
  opt :zz, "z opt", cls: Optimist::Int32Opt
end

opts.each { |k,v| p [k, v.value, v.given?] }

puts "xx class is #{typeof(opts["xx"])}"
puts "yy class is #{typeof(opts["yy"])}"
puts "zz class is #{typeof(opts["zz"])}"
