require "../src/optimist"

opts = Optimist.options do
  synopsis "Overall synopsis of this program"
  version "cool-script v0.3.1 (code-name: apple-cake)"
  banner "My Banner"
  opt :juice, "use juice"
  opt :milk, "use milk"
  opt :litres, "quantity of liquid", default: 2.0
  opt :brand, "brand name of the liquid", cls: Optimist::StringOpt
end

opts.each { |k, v| p [k, v.value, v.given?] }
