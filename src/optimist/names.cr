module Optimist
  class LongNames
    @truename : String?
    @long : String?
    @alts : Array(String)

    def initialize(@truename : String, lopt : LongNameType, alts : AlternatesType)
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

    # long specified with :long has precedence over the true-name
    def long
      @long || @truename.to_s
    end

    # all valid names, including alts
    def names : Array(String)
      [long.to_s] + @alts
    end
  end

  class ShortNames
    INVALID_ARG_REGEX = /[\d-]/

    getter :chars, :auto

    def initialize(value : ShortNameType)
      @chars = [] of String
      @auto = true
      self.add(value)
    end

    # Add a single character option
    def add(value : Char)
      raise ArgumentError.new("short option name '#{value}' must be an alphanumeric character") unless value.ascii_alphanumeric?
      @chars << value.to_s
    end

    # Overload for String
    def add(value : String)
      valsize = value.size
      return self.add(value.char_at(0)) if valsize == 1
      return self.add(value.char_at(1)) if valsize == 2 && value[0] == '-'
      raise ArgumentError.new("invalid short option name #{value.inspect}, must be in the form of 'x' or '-x'")
    end
    
    #SingleShortNameType)
    #  sopt if value.is_a?(String)
    #    
    #  sopt = case (strval = value.to_s)
    #         when /^-(.)$/ then $1
    #         when /^.$/    then strval
    #         else               raise 
    #         end
    ##if sopt =~ INVALID_ARG_REGEX
    #  #  raise ArgumentError.new("short option name '#{sopt}' can't be a number or a dash")
    #  #end
    #  @chars << sopt
    #end

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
