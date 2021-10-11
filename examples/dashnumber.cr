require "../src/optimist"

opts = Optimist.options do
  opt :cone, "cones", cls: Float64
  opt :zone, "zones", cls: Int32
  opt :sfo,  "stringflag", cls: Optimist::StringFlagOpt
  opt :aaa, "aaa"
  opt :a1b, "a1b"
  opt :a2b, "a2b"
  opt :bone, "bones", cls: Bool, short: '1'
  opt :nine, "nine", cls: Int32, short: '9'
  opt :five, "five", cls: Bool, short: '5', multi: true
end

opts.each { |k, v| p [k, v.value, v.given?] }
