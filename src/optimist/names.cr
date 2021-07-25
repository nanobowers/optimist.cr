module Optimist
  
class LongNames
  
  @truename : Symbol?
  @long : String?
  
  def initialize
    @truename = nil
    @long = nil
    @alts = [] of String
  end
  
  def make_valid(lopt : String) : String
    case lopt
    when /^--([^-].*)$/ then $1
    when /^[^-]/        then lopt
    else
      raise ArgumentError.new("invalid long option name #{lopt.inspect}")
    end
  end
  
  def set(name : Symbol, lopt : String?, alts : AlternatesType)
    @truename = name
    valid_lopt = case lopt
                     in String
                     lopt
                     in Nil
                     name.to_s.gsub("_", "-")
                 end
    @long = make_valid(valid_lopt)
    @alts = case alts
                in String
                [ make_valid(alts) ]
                in Array(String)
                alts.map { |a| make_valid(a) }
                in Nil
                [] of String
            end
  end
  
  # long specified with :long has precedence over the true-name
  def long ; @long || @truename.to_s ; end

  # all valid names, including alts
  def names
    [long] + @alts
  end
  
end

class ShortNames

  INVALID_ARG_REGEX = /[\d-]/

  getter :chars, :auto

  def initialize
    @chars = [] of String
    @auto = true
  end
  
  def add(values)
    values = [values] unless values.is_a?(Array) # box the value
    values.compact.each do |val|
      if val == :none
        @auto = false
        raise "Cannot set short to :none if short-chars have been defined '#{@chars}'" unless chars.empty?
        next
      end
      strval = val.to_s
      sopt = case strval
             when /^-(.)$/ then $1
             when /^.$/ then strval
             else raise ArgumentError.new("invalid short option name '#{val.inspect}'")
             end

      if sopt =~ INVALID_ARG_REGEX
        raise ArgumentError.new("short option name '#{sopt}' can't be a number or a dash")
      end
      @chars << sopt
    end
  end
  
end

end
