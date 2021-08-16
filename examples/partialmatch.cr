require "../src/optimist"

opts = Optimist.options do
  opt :apple, "An apple"
  opt :apple_sauce, "Cooked apple puree"
  opt :atom, "Smallest unit of ordinary matter"
  opt :anvil, "Heavy metal"
  opt :anteater, "Eats ants"
end

opts.each { |k, v| p [k, v.value, v.given?] }
