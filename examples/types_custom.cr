require "../src/optimist"

class ZipCode
  def initialize(@zip : String, @plusfour : String)
  end

  def inspect
    @zip + "-" + @plusfour
  end
end

class ZipCodeOpt < Optimist::Option
  ZIP_REGEX = /^(?<zip>[0-9]{5})(\-(?<plusfour>[0-9]{4}))?$/
  @default : ZipCode?
  getter :default
  setter :value

  def value
    @default || @value
  end

  def type_format
    "=<zip>"
  end # For use with help-message
  def add_argument_value(paramlist : Array(String), _neg_given)
    param = paramlist.first
    matcher = ZIP_REGEX.match(param)
    if matcher.is_a?(Regex::MatchData)
      @value = ZipCode.new(zip: matcher["zip"], plusfour: matcher["plusfour"]? || "0000")
    else
      raise Optimist::CommandlineError.new("Option '#{self.name}' should be formatted as a zipcode: ##### or #####-####")
    end
    @given = true
  end
end

opts = Optimist.options do
  opt :zipcode, "United states postal code", cls: ZipCodeOpt, default: ZipCode.new(zip: "90210", plusfour: "5555")
end

p opts["zipcode"].value
