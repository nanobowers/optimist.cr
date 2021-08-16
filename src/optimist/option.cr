module Optimist
  abstract class Option
    abstract def default
    abstract def add_argument_value(a : Array(String), b : Bool)
    abstract def value

    getter :short
    property :name, :long, :permitted, :permitted_response
    property :callback, :desc
    property? :required
    getter? :given

    # defaults
    @name : String
    @permitted : PermittedType
    @callback : Option -> Nil
    @desc : String
    @given : Bool
    @arguments_applied : Int32

    def initialize(name, @desc, default : T) forall T
      @long = LongNames.new
      # can be an Array of one-char strings, a one-char String, nil or false
      @short = ShortNames.new
      @callback = ->(x : Option) {}
      @name = "__unknown__"
      # @desc = ""
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

    def needs_an_argument
      true
    end # flag-like options do not need arguments
    def takes_an_argument
      true
    end # flag-only options do not take an argument
    def takes_multiple
      @max_args > 1
    end # overridden in array-versions

    def trigger_callback
      @callback.call(self)
    end

    def disallow_multiple_args(paramlist : Array(String))
      if self.given? || paramlist.size > 1
        raise CommandlineError.new("Option '#{self.name}' cannot be given more than once")
      end
    end

    getter :min_args, :max_args

    # |@min_args | @max_args |
    # +----------+-----------+
    # | 0        | 0         | formerly flag?==true (option without any arguments)
    # | 1        | 1         | formerly single_arg?==true (single-parameter/normal option)
    # | 1        | >1        | formerly multi_arg?==true

    # # TODO: push into SHORT
    def doesnt_need_autogen_short
      !short.auto || !short.chars.empty?
    end

    # Provide type-format string.
    # Default to empty, but should probably be overridden for most
    # subclasses.
    def type_format
      ""
    end

    def educate
      optionlist = [] of String
      optionlist.concat(short.chars.map { |o| "-#{o}" })
      optionlist.concat(long.names.map { |o| "--#{o}" })
      optionlist.compact.join(", ") + type_format + (min_args == 0 && default ? ", --no-#{long.to_s}" : "")
    end

    # # Format the educate-line description including the default and permitted value(s)
    def full_description
      desc_str = desc
      desc_str = description_with_default desc_str if default
      desc_str = description_with_permitted desc_str if permitted
      desc_str
    end

    # # Format stdio like objects to a string
    def format_stdio(obj)
      case obj
      when STDOUT then "<stdout>"
      when STDIN  then "<stdin>"
      when STDERR then "<stderr>"
      else             obj # pass-through-case
      end
    end

    # # Format the educate-line description including the default-value(s)
    def description_with_default(str)
      return str unless default
      return "#{str} (Default: #{default.inspect})"
    end

    # # Format the educate-line description including the permitted-value(s)
    def description_with_permitted(str)
      permitted_s = case permitted
                    in Array
                      permitted.as(Array).map do |p|
                        format_stdio(p).to_s
                      end.join(", ")
                    in Range
                      permitted.as(Range).to_a.map(&.to_s).join(", ")
                    in Regex
                      permitted.inspect
                    in Nil
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
        format_hash = {arg: arg, given: value, value: value, valid_string: permitted_valid_string(permitted), permitted: permitted}
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

    # # Factory class method
    # Determines which type of object to create based on arguments passed
    # to +Optimist::opt+.  This is tricky because we allow the +default:+
    # to be able to set the option's type.
    def self.create(name, desc,
                    cls : Class? = nil,
                    long : LongNameType = nil,
                    alt : AlternatesType = nil,
                    short : ShortNameType = nil,
                    multi : Bool = false,
                    default : _ = nil,
                    permitted : PermittedType = nil,
                    permitted_response : String? = nil,
                    required : Bool = false,
                    **opts, &block : Option -> Nil)
      if cls.is_a?(Nil)
        if default.is_a?(Int32)
          opt_inst = Int32Opt.new(name, desc, default)
        elsif default.is_a?(Bool)
          opt_inst = BoolOpt.new(name, desc, default)
        elsif default.is_a?(String)
          opt_inst = StringOpt.new(name, desc, default)
        elsif default.is_a?(Array(String))
          opt_inst = StringArrayOpt.new(name, desc, default)
        elsif default.is_a?(Float)
          opt_inst = Float64Opt.new(name, desc, default)
        elsif default.is_a?(IO::FileDescriptor)
          opt_inst = FileOpt.new(name, desc, default)
        else
          # No class and no default given, so this is an implicit
          # flag (BoolOpt)

          opt_inst = BoolOpt.new(name, desc, default.nil? ? false : default.as(Bool))
        end
      else
        opt_inst = cls.new(name, desc, default)
      end

      opt_inst.long.set(name, long, alt) # # fill in long/alt opts
      opt_inst.short.add short           # # fill in short opts

      # # Fill in permitted values
      opt_inst.permitted = permitted.as(PermittedType)
      opt_inst.permitted_response = permitted_response if permitted_response
      opt_inst.name = name
      opt_inst.required = required

      # # Set multi (affects BoolOpt only)
      if opt_inst.is_a?(BoolOpt)
        opt_inst.multi = multi
      end

      opt_inst.callback = block

      return opt_inst # some sort of Option
    end
  end

  ################################################
  ################################################
  ################################################

  # Flag option.  Has no arguments. Can be negated with "no-".
  class BoolOpt < Option
    @value : Bool?
    @default : Bool?
    @multi : Bool

    property :multi
    getter :default
    setter :value

    def initialize(name, desc, default : Bool?)
      super
      @multi = false
      @value = nil
      @default = default.nil? ? false : default
      @min_args = 0
      @max_args = 0
    end

    def value
      return @value.nil? ? @default : @value
    end

    def takes_multiple
      @multi
    end

    def add_argument_value(_paramlist : Array(String), neg_given)
      @value = (self.name.to_s =~ /^no_/) ? neg_given : !neg_given
      @given = true
    end

    def needs_an_argument
      false
    end

    def takes_an_argument
      false
    end
  end

  # Integer number option class.
  class Int32Opt < Option
    @value : Int32?
    @default : Int32?
    getter :default
    setter :value

    def initialize(name, desc, default : Int32?)
      super
      @value = nil
      @default = default
    end

    def value
      return @value.nil? ? @default : @value
    end

    def add_argument_value(val : String)
      @value = val.to_i
    end

    def type_format
      "=<i>"
    end

    def add_argument_value(paramlist : Array(String), _neg_given)
      param = paramlist.first
      unless param =~ INT_RE
        raise CommandlineError.new("option '#{self.name}' needs an integer number")
      end
      @value = param.to_i
      @given = true
    end
  end

  # Floating point number option class.
  class Float64Opt < Option
    @value : Float64?
    @default : Float64?
    getter :default
    setter :value

    def initialize(name, desc, @default : Float64?)
      super
      @value = nil
    end

    def value
      return @value.nil? ? @default : @value
    end

    def type_format
      "=<f>"
    end

    def add_argument_value(paramlist : Array(String), _neg_given)
      disallow_multiple_args(paramlist)
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
  class FileOpt < Option
    @value : IO::FileDescriptor?
    @default : IO::FileDescriptor?
    getter :default
    setter :value

    def value
      return @value.nil? ? @default : @value
    end

    def type_format
      "=<filename/uri>"
    end

    def add_argument_value(paramlist : Array(String), _neg_given)
      param = paramlist.first
      @value = if param =~ /^(stdin|\-)$/i
                 STDIN
               else
                 begin
                   File.open(param)
                 rescue File::NotFoundError
                   raise CommandlineError.new("Error opening file '#{param}' given with '#{self.name}'")
                 end
               end

      @given = true
    end
  end

  # Option class for handling Strings.
  class StringOpt < Option
    @value : String?
    @default : String?
    property :value
    getter :default

    def value
      return @value.nil? ? @default : @value
    end

    def type_format
      "=<s>"
    end

    def add_argument_value(paramlist : Array(String), _neg_given)
      @value = paramlist.first
      @given = true
    end
  end

  #
  class StringFlagOpt < StringOpt
    @value : String?
    @default : String?
    setter :value
    getter :default

    def value : String?
      return @default if @value.nil?
      @value
    end

    def initialize(name, desc, @default : String?)
      super
      # @default = default.nil? ? false : default
      @min_args = 0
      @max_args = 1
    end

    def type_format
      "=<s?>"
    end

    def add_argument_value(paramlist : Array(String), neg_given)
      @given = true
      @value = case paramlist.size
               when 0 then nil
               when 1 then paramlist.first
               else        raise ArgumentError.new("Too many params given")
               end
    end

    # can take an argument but doesnt need one.
    def needs_an_argument
      false
    end
  end

  ###
  ###
  # ##  ### MULTI_OPT_TYPES :
  # ##  ## The set of values that indicate a multiple-parameter option (i.e., that
  # ##  ## takes multiple space-separated values on the commandline) when passed as
  # ##  ## the +:type+ parameter of #opt.
  ###
  # ##  # Option class for handling multiple Integers
  class Int32ArrayOpt < Option
    def type_format
      "=<i+>"
    end

    @value : Array(Int32)
    @default : Array(Int32)
    property :value
    getter :default

    def add_argument_value(paramlist : Array(String), _neg_given)
      int_paramlist = paramlist.map do |strparam|
        unless strparam =~ INT_RE
          raise CommandlineError.new("option '#{self.name}' needs an integer number, cannot handle #{strparam}")
        end
        strparam.to_i
      end
      @value.concat int_paramlist
      @given = true
    end

    def initialize(name, desc, default : Array(Int32)?)
      # if default is given as nil, set as an empty array.
      super(name, desc, default || [] of Int32)
      @value = [] of Int32
      @max_args = 999
    end

    # For object duplication case we need to return an invalidated object
    # so reset the value/given fields which are filled in by the option.
    def dup
      super
      @value = [] of Int32
      @given = false
      self
    end
  end

  ###

  # Option class for handling multiple Floats
  class Float64ArrayOpt < Option
    def type_format
      "=<f+>"
    end

    @value : Array(Float64)
    @default : Array(Float64)
    property :value
    getter :default

    def add_argument_value(paramlist : Array(String), _neg_given)
      float_paramlist = paramlist.map do |strparam|
        unless strparam =~ FLOAT_RE
          raise CommandlineError.new("option '#{self.name}' needs a floating-point number, cannot handle #{strparam}")
        end
        strparam.to_f
      end

      @value.concat float_paramlist
      @given = true
    end

    def initialize(name, desc, default : Array(Float64)?)
      # if default is given as nil, set as an empty array.
      super(name, desc, default || [] of Float64)
      @value = [] of Float64
      @max_args = 999
    end

    # For object duplication case we need to return an invalidated object
    # so reset the value/given fields which are filled in by the option.
    def dup
      super
      @value = [] of Float64
      @given = false
      self
    end
  end

  # Option class for handling multiple Strings
  class StringArrayOpt < Option
    @value : Array(String)
    @default : Array(String)
    setter :value
    getter :default

    def value
      return @default if @value.empty?
      @value
    end

    def type_format
      "=<s+>"
    end

    def add_argument_value(paramlist : Array(String), _neg_given)
      @value.concat paramlist
      @given = true
    end

    def initialize(name, desc, default : Array(String)?)
      # if default is given as nil, set as an empty array.
      super(name, desc, default || [] of String)
      @value = [] of String
      @max_args = 999
    end

    # For object duplication case we need to return an invalidated object
    # so reset the value/given fields which are filled in by the option.
    def dup
      super
      @value = [] of String
      @given = false
      self
    end
  end
end
