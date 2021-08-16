require "../src/optimist"

opts = Optimist.options do
  opt :log, "specify optional log-file path", cls: Optimist::StringFlagOpt, default: "progname.log"
end

opts.each { |k, v| p [k, v.value, v.given?] }
