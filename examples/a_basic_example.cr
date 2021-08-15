#!/usr/bin/env ruby
require "../src/optimist"

opts = Optimist.options do
  opt :monkey, "Use monkey mode"                      # flag --monkey, default false
  opt :name, "Monkey name", cls: Optimist::StringOpt  # string --name <s>, default nil
  opt :num_limbs, "Number of limbs", default: 4       # integer --num-limbs <i>, default to 4
end

opts.each { |k,v| p [k, v.value, v.given?] }

