module Optimist
  class LongNames
    @truename : String?
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

    def to_s : String
      @long.to_s
    end

    def set(@truename : String, lopt : LongNameType, alts : AlternatesType)
      valid_lopt = case lopt
                   in String
                     lopt.to_s
                   in Nil
                     @truename.to_s.gsub("_", "-")
                   end
      @long = make_valid(valid_lopt)
      @alts = case alts
              in String
                [make_valid(alts.to_s)]
              in Array(String)
                alts.map { |a| make_valid(a.to_s) }
              in Nil
                [] of String
              end
    end

    # long specified with :long has precedence over the true-name
    def long
      @long || @truename.to_s
    end

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

    # Overload for char/string
    def add(value : SingleShortNameType)
      sopt = case (strval = value.to_s)
             when /^-(.)$/ then $1
             when /^.$/    then strval
             else               raise ArgumentError.new("invalid short option name '#{value.inspect}'")
             end

      if sopt =~ INVALID_ARG_REGEX
        raise ArgumentError.new("short option name '#{sopt}' can't be a number or a dash")
      end
      @chars << sopt
    end

    # Overload for true/false values
    def add(value : Bool?)
      case value
      in true
        raise ArgumentError.new("cannot use value 'true' in short-chars")
      in nil
        # do nothing
      in false
        @auto = false
        raise ArgumentError.new("cannot set short to false if short-chars have been defined '#{@chars}'") unless @chars.empty?
      end
    end

    # Handle an Array of Char/String
    def add(values : MultiShortNameType)
      values.each { |v| add(v) }
    end
  end
end
