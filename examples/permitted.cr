require "../src/optimist"

include Optimist

opts = Optimist.options do
  opt :french, "starts with french", cls: StringOpt,
    permitted: %w(fries toast),
    permitted_response: "option %{arg} must be something that starts " +
                        "with french, e.g. %{permitted} but you gave '%{given}'"

  opt :dog, "starts with dog", permitted: /(house|bone|tail)/, cls: StringOpt

  opt :zipcode, "zipcode", permitted: /^[0-9]{5}$/, default: "39759",
    permitted_response: "option %{arg} must be a zipcode, a five-digit number from 00000..99999"
end

opts.each { |k, v| p [k, v.value, v.given?] }
