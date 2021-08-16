require "../src/optimist"

opts = Optimist.options do
  version "cool-script v0.3.2 (code-name: apple-cake)"
  banner version.to_s # # print out the version in the banner
  banner "drinks"
  opt :juice, "use juice"
  opt :milk, "use milk"
  banner "drink control" # # can be used for categories
  opt :litres, "quantity of liquid", default: 2.0
  opt :brand, "brand name of the liquid", cls: Optimist::StringOpt
  banner "other controls"
end

opts.each { |k, v| p [k, v.value, v.given?] }
