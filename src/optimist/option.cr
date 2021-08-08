module Optimist

  abstract class Option

    abstract def default
    abstract def add_argument_value(a  : Array(String), b : Bool)
    abstract def value
        
    getter :short
    property :name, :long, :permitted, :permitted_response

    # defaults
    @name : String
    #@default : T?
    @permitted : PermittedType
    @callback : Proc(String,String)?
    @desc : String
    @given : Bool
    @arguments_applied : Int32
    
    def initialize(name, desc, default : T) forall T
      @long = LongNames.new
      # can be an Array of one-char strings, a one-char String, nil or false
      @short = ShortNames.new
      @callback = nil
      @name = "__unknown__"
      @desc = ""
      #@multi_given = false
      @hidden = false
      @default = default
      @permitted = nil
      @permitted_response = "option '%{arg}' only accepts %{valid_string}"
      @required = false
      @arguments_applied = 0
      @min_args = 1
      # note: maximum max_args is likely ~~ 128*1024, as
      # linux MAX_ARG_STRLEN is 128kiB
      @max_args = 1

      # Was the option given or not. SET BY *PARSE*
      @given = false
    end

    def multi ; false ; end

    # Check that an option is compatible with another option.
    # By default, checking that they are the same class, but we
    # can override this in the subclass as needed.
    def compatible_with?(other_option)
      typeof(self) == typeof(other_option)
    end

    #def multi ; @multi_given ; end


    getter :min_args, :max_args
    # |@min_args | @max_args |
    # +----------+-----------+
    # | 0        | 0         | formerly flag?==true (option without any arguments)
    # | 1        | 1         | formerly single_arg?==true (single-parameter/normal option)
    # | 1        | >1        | formerly multi_arg?==true 
    # | ?        | ?         | presumably illegal condition. untested.
    
    #kill# def array_default? ; self.default.is_a?(Array) ; end

    ## TODO: push into SHORT
    def doesnt_need_autogen_short ; !short.auto || !short.chars.empty? ; end

    property :callback, :desc
    
    getter? :required

    # provide type-format string.  default to empty, but user should probably override it
    def type_format ; "" ; end

    def educate
      optionlist = [] of String
      optionlist.concat(short.chars.map { |o| "-#{o}" })
      optionlist.concat(long.names.map { |o| "--#{o}" })
      optionlist.compact.join(", ") + type_format + (min_args==0 && default ? ", --no-#{long}" : "")
    end

    ## Format the educate-line description including the default and permitted value(s)
    def full_description
      desc_str = desc
      desc_str = description_with_default desc_str if default
      #TODO
      desc_str = description_with_permitted desc_str if permitted
      desc_str
    end

    ## Format stdio like objects to a string
    def format_stdio(obj)
      case obj
      when STDOUT   then "<stdout>"
      when STDIN    then "<stdin>"
      when STDERR   then "<stderr>"
      else obj # pass-through-case
      end
    end
    
    ## Format the educate-line description including the default-value(s)
    def description_with_default(str)
      return str unless default
      #OLD# default_s = if default.is_a?(Array)
      #OLD#              default.join(", ")
      #OLD#            else
      #OLD#              format_stdio(default).to_s
      #OLD#            end
      default_s = default.inspect
      return "#{str} (Default: #{default_s})"
    end

    ## Format the educate-line description including the permitted-value(s)
    def description_with_permitted(str)
      permitted_s = case permitted
                        in Array
                        permitted.as(Array).map do |p|
                          format_stdio(p).to_s
                        end.join(", ")
                        in Range
                        permitted.as(Range).to_a.map(&.to_s).join(", ")
                        in Regex, Nil
                        permitted.to_s
                    end
      return "#{str} (Permitted: #{permitted_s})"
    end

    # Format permitted string
    
    def permitted_valid_string(permitted : Array) : String
      "one of: " + permitted.map(&.to_s).join(", ")
    end
    def permitted_valid_string(permitted : Range) : String
      "value in range of: #{permitted}"
    end
    def permitted_valid_string(permitted : Regex) : String
      "value matching: #{permitted.inspect}"
    end
    def permitted_valid_string(permitted : Nil)
      "unpermitted"
    end
    
    def permitted_type_valid?
      return true if permitted.nil?
      return true if permitted.is_a? Array
      return true if permitted.is_a? Range
      return true if permitted.is_a? Regex
      false
    end

    def validate_permitted(arg : String, value : DefaultType) : Void
      return true if permitted.nil?
      unless permitted_value?(value)
        format_hash = {arg: arg, given: value, value: value, valid_string: permitted_valid_string(permitted), permitted: permitted }
        raise CommandlineError.new(permitted_response % format_hash)
      end
    end
    
    # incoming values from the command-line should be strings, so we should
    # stringify any permitted types as the basis of comparison.
    def permitted_value?(val : DefaultType) : Bool
      valstr = val.to_s
      case @permitted
           in Regex
           return !((@permitted =~ valstr).nil?)
           in Array
           return permitted.as(Array).map(&.to_s).includes? valstr
           in Range
           return permitted.as(Range).to_a.map(&.to_s).includes? valstr
           in Nil
           return true
      end
    end  
    
    ## Factory class method
    # Determines which type of object to create based on arguments passed
    # to +Optimist::opt+.  This is tricky because we allow the +default:+
    # to be able to set the option's type.
    def self.create(name, desc,
                    cls : Class? = nil,
                    long : String? = nil,
                    alt : AlternatesType = nil,
                    short : (String|Bool|Nil|Char) = nil,
                    multi : Bool = false,
                    default : DefaultType = nil,
                    permitted : PermittedType = nil,
                    permitted_response : String? = nil,
                    required : Bool = false,
                    **opts)

      if cls.is_a?(Nil)
        if default.is_a?(Int)
          opt_inst = IntOption.new(name, desc, default)
        elsif default.is_a?(Bool)
          opt_inst = BooleanOption.new(name, desc, default)
        elsif default.is_a?(String)
          opt_inst = StringOption.new(name, desc, default)
        elsif default.is_a?(Array(String))
          opt_inst = StringArrayOption.new(name, desc, default)
        elsif default.is_a?(Float)
          opt_inst = FloatOption.new(name, desc, default)
        elsif default.is_a?(IO::FileDescriptor)
          opt_inst = IOOption.new(name, desc, default)
        else # nil??
          opt_inst = BooleanOption.new(name, desc, default)
          default = false
        end
      else
        opt_inst = cls.new(name, desc, default)
      end
      
      opt_inst.long.set(name, long, alt)   ## fill in long/alt opts
      opt_inst.short.add short             ## fill in short opts

      ## fill in permitted values
      opt_inst.permitted = permitted
      opt_inst.permitted_response = permitted_response if permitted_response
      opt_inst.name = name

      return opt_inst # some sort of Option
    end

    def self.handle_long_opt(lopt, name)
      lopt = lopt ? lopt.to_s : name.to_s.gsub("_", "-")
      lopt = case lopt
             when /^--([^-].*)$/ then $1
             when /^[^-]/        then lopt
             else                     raise ArgumentError.new("invalid long option name #{lopt.inspect}")
             end
    end

    def self.handle_short_opt(sopt)
      sopt = sopt.to_s if sopt && sopt != false
      sopt = case sopt
             when /^-(.)$/          then $1
             when nil, false, /^.$/ then sopt
             else                   raise ArgumentError.new("invalid short option name '#{sopt.inspect}'")
             end

      if sopt
        raise ArgumentError.new("a short option name can't be a number or a dash") if sopt =~ ::Optimist::Parser::INVALID_SHORT_ARG_REGEX
      end
      return sopt
    end
    
  end

  ################################################
  ################################################
  ################################################
  
  # Flag option.  Has no arguments. Can be negated with "no-".
  class BooleanOption < Option
    @value : Bool?
    @default : Bool?
    getter :value, :default
    def initialize(name, desc, default : Bool?)
      super
      @value = nil
      @default = default.nil? ? false : default
      @min_args = 0
      @max_args = 0
    end
    
    def add_argument_value(_paramlist : Array(String), neg_given)
      @value = (self.name.to_s =~ /^no_/) ? neg_given : !neg_given
      @given = true
    end
    def multi : Bool ; false ; end
  end

  # Integer number option class.
  class IntOption < Option
    @value : Int32?
    @default : Int32?
    getter :value, :default
    
    def initialize(name, desc, default : Int32?)
      super
      @value = nil
      @default = default
    end

    def add_argument_value(val : String)
      @value = val.to_i
    end
    
    def multi : Bool ; false ; end
    def type_format ; "=<i>" ; end
    def add_argument_value(paramlist : Array(String), _neg_given)
      param = paramlist.first
      unless param =~  /^-?[\d_]+$/
        raise CommandlineError.new("option '#{self.name}' needs a floating-point number")
      end
      @value = param.to_i
      @given = true
    end
  end

  # Floating point number option class.
  class FloatOption < Option
    @value : Float64?
    @default : Float64?
    getter :value, :default
    def initialize(name, desc, default : Float64?)
      super
      @value = nil
      @default = default
    end
    def multi : Bool ; false ; end
    
    def type_format ; "=<f>" ; end
    def add_argument_value(paramlist : Array(String), _neg_given)
      param = paramlist.first
      unless param =~ FLOAT_RE
        raise CommandlineError.new("option '#{self.name}' needs a floating-point number")
      end
      @value = param.to_f
      @given = true
    end
  end


  # Option class for handling IO objects and URLs.
  # Note that this will return the file-handle, not the file-name
  # in the case of file-paths given to it.
  class IOOption < Option
    
    @value : IO::FileDescriptor?
    @default : IO::FileDescriptor?
    getter :value, :default
    def multi : Bool ; false ; end
    def type_format ; "=<filename/uri>" ; end
    def add_argument_value(paramlist : Array(String), _neg_given)
      param = paramlist.first
      @value = if param =~ /^(stdin|\-)$/i
                 STDIN
               else
                 File.open(param)
               end
      @given = true
    end
  end

  # Option class for handling Strings.
  class StringOption < Option
    @value : String?
    @default : String?
    getter :value, :default
    
    def multi : Bool ; false ; end
    def type_format ; "=<s>" ; end
    def add_argument_value(paramlist : Array(String), _neg_given)
      @value = paramlist.first
      @given = true
    end
  end

  # 
  class StringFlagOption < StringOption
    @value : String?
    @default : String?
    getter :value, :default
    def initialize(name, desc, @default : String?)
      super
      #@default = default.nil? ? false : default
      @min_args = 0
      @max_args = 1
    end
    def multi : Bool ; false ; end
    def type_format ; "=<s?>" ; end
    def add_argument_value(paramlist : Array(String), neg_given)
      @given = true
      
      @value = case paramlist.size
               when 0 then nil
               when 1 then paramlist.first
               else raise ArgumentError.new("Too many params given")
               end
    end
    def compatible_with?(other_option)
      selftype = typeof(self)
      selftype == typeof(other_option) ||
        typeof(other_option) == BooleanOption ||
        typeof(other_option) == StringArrayOption
    end

  end

###
###
###  ### MULTI_OPT_TYPES :
###  ## The set of values that indicate a multiple-parameter option (i.e., that
###  ## takes multiple space-separated values on the commandline) when passed as
###  ## the +:type+ parameter of #opt.
###
###  # Option class for handling multiple Integers
###  class IntArrayOption < IntOption
###    def multi ; true ; end
###    def type_format ; "=<i+>" ; end
###    #def initialize ; super ; @max_args = 999 ; end
###  end
###
###  # Option class for handling multiple Floats
###  class FloatArrayOption < FloatOption
###    def type_format ; "=<f+>" ; end
###    #def initialize ; super ; @max_args = 999 ; end
###  end
###
###  # Option class for handling multiple Strings
  class StringArrayOption < Option
    @value : Array(String)
    @default : Array(String)
    getter :value, :default
    
    def multi : Bool ; false ; end
    def type_format ; "=<s+>" ; end
    def add_argument_value(paramlist : Array(String), _neg_given)
      @value.concat paramlist
      @given = true
    end
    def initialize
      super
      @value = [] of String
    end
  end
###
###  # Option class for handling Files/URLs via 'open'
###  class IOArrayOption < IOOption
###    def type_format ; "=<filename/uri+>" ; end
###    #def initialize(name ; super ; @max_args = 999 ; end
###  end

end
