module Optimist
  alias CbType = (Option -> Nil) | Nil

  abstract class Option
    abstract def default
    abstract def add_argument_value(a : Array(String), b : Bool)
    abstract def value

    getter :desc
    getter :long
    getter :name
    getter :permitted
    getter :permitted_response
    getter :short
    getter? :given
    getter? :required

    # defaults
    @given : Bool

    def initialize(@name : String, @desc : String, @default : T,
                   long : LongNameType = nil,
                   alt : AlternatesType = nil,
                   short : ShortNameType = nil,
                   @permitted : PermittedType = nil,
                   @callback : ((Option -> Nil) | Nil) = nil,
                   @permitted_response : String = "option '%{arg}' only accepts %{valid_string}",
                   @required : Bool = false,
                   @hidden : Bool = false,
                   @multi : Bool? = nil # unused except on boolean
                   ) forall T
      @long = LongNames.new(name, long, alt)
      @short = ShortNames.new(short)

      @min_args = 1
      @max_args = 1

      # Was the option given or not.
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
      if !@callback.nil?
        @callback.as(Option -> Nil).call(self)
      end
    end

    def disallow_multiple_args(paramlist : Array(String))
      if self.given? || paramlist.size > 1
        raise CommandlineError.new("Option '#{self.name}' cannot be given more than once")
      end
    end

    getter :min_args, :max_args

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

    # Format the educate-line description including the
    # default and permitted value(s)
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

    # Incoming values from the command-line should be strings, so we should
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

    # Factory class method
    # Determines which type of object to create based on arguments passed
    # to +Optimist::opt+.  This is tricky because we allow the +default:+
    # to be able to set the option's type.
    def self.create(name : String,
                    desc : String,
                    cls : Class? = nil,
                    default : _ = nil,
                    **kwargs)
      if cls.is_a?(Nil)
        if default.is_a?(Int32)
          opt_inst = Int32Opt.new(name, desc, default, **kwargs)
        elsif default.is_a?(Bool)
          opt_inst = BoolOpt.new(name, desc, default, **kwargs)
        elsif default.is_a?(String)
          opt_inst = StringOpt.new(name, desc, default, **kwargs)
        elsif default.is_a?(Array(String))
          opt_inst = StringArrayOpt.new(name, desc, default, **kwargs)
        elsif default.is_a?(Float)
          opt_inst = Float64Opt.new(name, desc, default, **kwargs)
        elsif default.is_a?(IO::FileDescriptor)
          opt_inst = FileOpt.new(name, desc, default, **kwargs)
        else
          # No class and no default given, so this is an implicit
          # flag (BoolOpt)
          booldefault = default.nil? ? false : default.as(Bool)
          opt_inst = BoolOpt.new(name, desc, booldefault, **kwargs)
        end
      elsif cls.is_a?(Bool.class)
        opt_inst = BoolOpt.new(name, desc, default.as(Bool?), **kwargs)
      elsif cls.is_a?(Int32.class)
        opt_inst = Int32Opt.new(name, desc, default.as(Int32?), **kwargs)
      elsif cls.is_a?(Float64.class)
        opt_inst = Float64Opt.new(name, desc, default.as(Float64?), **kwargs)
      elsif cls.is_a?(String.class)
        opt_inst = StringOpt.new(name, desc, default.as(String?), **kwargs)
      else
        opt_inst = cls.new(name, desc, default, **kwargs)
      end

      return opt_inst # some sort of Option
    end
  end

  ################################################
  ################################################
  ################################################

  # Flag option.  Has no arguments. Can be negated with "no-".
  # Allows multiple of the same option to be given if multi: is given.
  class BoolOpt < Option
    @value : Bool?
    @default : Bool

    property :multi
    property :counter
    getter :default
    setter :value

    def initialize(name, desc, default : Bool? = nil, **kwargs)
      booldefault = default.nil? ? false : default
      super(name, desc, booldefault, **kwargs)
      @value = nil
      @min_args = 0
      @max_args = 0
      @counter = 0
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
      @counter += 1
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

    def initialize(name, desc, default : Int32?, **kwargs)
      super(name, desc, default, **kwargs)
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

    def initialize(name, desc, default : Float64?, **kwargs)
      super(name, desc, default, **kwargs)
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

    def initialize(name, desc, default : IO?, **kwargs)
      super(name, desc, default, **kwargs)
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

    def initialize(name, desc, default : String?, **kwargs)
      super(name, desc, default, **kwargs)
    end

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

  class StringFlagOpt < Option
    alias StringFlagType = String | Bool | Nil
    @value : StringFlagType
    @default : String?
    setter :value
    getter :default

    def value : StringFlagType
      return @default || false if @value.nil?
      @value
    end

    def initialize(name, desc, default : String?, **kwargs)
      super(name, desc, default, **kwargs)
      @min_args = 0
      @max_args = 1
    end

    def type_format
      "=<s?>"
    end

    def add_argument_value(paramlist : Array(String), neg_given)
      @given = true
      @value = case paramlist.size
               when 0
                 if neg_given
                   # when --no-opt is given, force false
                   false
                 else
                   @default || true
                 end
               when 1
                 paramlist.first
               else
                 raise ArgumentError.new("Too many params given")
               end
    end

    # can take an argument but doesnt need one.
    def needs_an_argument
      false
    end
  end

  # Option class for handling multiple Integers
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

    def initialize(name, desc, default : Array(Int32)? = nil, **kwargs)
      # if default is given as nil, set as an empty array.
      super(name, desc, default || [] of Int32, **kwargs)
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

    def initialize(name, desc, default : Array(Float64)? = nil, **kwargs)
      # if default is given as nil, set as an empty array.
      super(name, desc, default || [] of Float64, **kwargs)
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

    def initialize(name, desc, default : Array(String)? = nil, **kwargs)
      # if default is given as nil, set as an empty array.
      super(name, desc, default || [] of String, **kwargs)
      # name, desc, default || [] of String, **kwargs)
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
