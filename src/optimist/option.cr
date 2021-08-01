module Optimist
  
  class Option
    
    getter :short
    property :name, :long, :default, :permitted, :permitted_response
    setter :multi_given

    # defaults
    @name : Symbol
    @default : DefaultType
    @permitted : PermittedType
    @callback : Proc(String,String)?
    @desc : String
    
    def initialize(name, desc, default)
      @long = LongNames.new
      # can be an Array of one-char strings, a one-char String, nil or false
      @short = ShortNames.new
      @callback = nil
      @name = :__unknown
      @desc = ""
      @multi_given = false
      @hidden = false
      @default = default
      @permitted = nil
      @permitted_response = "option '%{arg}' only accepts %{valid_string}"
      @required = false

      @min_args = 1
      # note: maximum max_args is likely ~~ 128*1024, as
      # linux MAX_ARG_STRLEN is 128kiB
      @max_args = 1
    end
    
    
    # Check that an option is compatible with another option.
    # By default, checking that they are the same class, but we
    # can override this in the subclass as needed.
    def compatible_with?(other_option)
      typeof(self) == typeof(other_option)
    end

#    def opts(key)
#      @optshash[key]
#    end

#    def opts=(o)
#      @optshash = o
#    end


    def multi ; @multi_given ; end
    #alias_method :multi?, :multi

    getter :min_args, :max_args
    # |@min_args | @max_args |
    # +----------+-----------+
    # | 0        | 0         | formerly flag?==true (option without any arguments)
    # | 1        | 1         | formerly single_arg?==true (single-parameter/normal option)
    # | 1        | >1        | formerly multi_arg?==true 
    # | ?        | ?         | presumably illegal condition. untested.
    
    def array_default? ; self.default.is_a?(Array) ; end

    def doesnt_need_autogen_short ; !short.auto || !short.chars.empty? ; end

    property :callback, :desc # def callback ; opts(:callback) ; end
    
    #def desc ; opts(:desc) ; end

    def required? ; @required ; end

    def parse(_paramlist, _neg_given)
      raise NotImplementedError.new("parse must be overridden for newly registered type")
    end

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
#TODO      desc_str = description_with_permitted desc_str if permitted
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
      #default_s = if default.is_a?(Array)
      #              default.join(", ")
      #            else
      #              format_stdio(default).to_s
      #            end
      default_s = default.inspect
      return "#{str} (Default: #{default_s})"
    end

    ## Format the educate-line description including the permitted-value(s)
    def description_with_permitted(str)
      permitted_s = case permitted
                    in Array
                      permitted.map do |p|
                        format_stdio(p).to_s
                      end.join(", ")
                    in Range
                      permitted.to_a.map(&.to_s).join(", ")
                    in Regex
                      permitted.to_s
                    end
      return "#{str} (Permitted: #{permitted_s})"
    end

    def permitted_valid_string
      case permitted
      in Array
        return "one of: " + permitted.to_a.map(&.to_s).join(", ")
      in Range
        return "value in range of: #{permitted}"
      in Regex
        return "value matching: #{permitted.inspect}"
      end
      raise Exception, "invalid branch"
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
        format_hash = {arg: arg, given: value, value: value, valid_string: permitted_valid_string(), permitted: permitted }
        raise CommandlineError.new(permitted_response % format_hash)
      end
    end
    
    # incoming values from the command-line should be strings, so we should
    # stringify any permitted types as the basis of comparison.
    def permitted_value?(val : DefaultType) : Bool
      valstr = val.to_s
      if @permitted.is_a?(Regex)
        return @permitted =~ valstr
      elsif permitted.is_a?(Array)
        return permitted.map(&.to_s).includes? valstr
      elsif permitted.is_a?(Range)
        return permitted.to_a.map(&.to_s).includes? valstr
      elsif permitted.nil?
        return true
      else
        false
      end
    end  
    


    ## Factory class methods ...

    # Determines which type of object to create based on arguments passed
    # to +Optimist::opt+.  This is trickier in Optimist, than other cmdline
    # parsers (e.g. Slop) because we allow the +default:+ to be able to
    # set the option's type.
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
      
      # p! opt_inst
      
      #opttype = Optimist::Parser.registry_getopttype(otype)
      #opttype_from_default = get_klass_from_default(opts, opttype)
      #DEBUG# puts "\nopt:#{opttype||"nil"} ofd:#{opttype_from_default}"  if opttype_from_default
      #if opttype && opttype_from_default && !opttype.compatible_with?(opttype_from_default) # opttype.is_a? opttype_from_default.class
      #  raise ArgumentError, ":type specification (#{opttype.class}) and default type don't match (default type is #{opttype_from_default.class})" 
      #end
      #opt_inst = (opttype || opttype_from_default || Optimist::BooleanOption.new)

      ## fill in :long
      opt_inst.long.set(name, long, alt)

      ## fill in :short
      opt_inst.short.add short

      ## fill in :multi

      opt_inst.multi_given = multi_given = multi

      ## autobox :default for :multi (multi-occurrence) arguments
      #defvalue = [defvalue] if defvalue && multi_given && !defvalue.kind_of?(Array)
      ## fill in permitted values
      opt_inst.permitted = permitted
      opt_inst.permitted_response = permitted_response if permitted_response
      #opt_inst.default = defvalue
      opt_inst.name = name
      #opt_inst.opts = opts

      
      opt_inst
    end


    def self.get_type_from_disdef(optdef, opttype, disambiguated_default)
      if disambiguated_default.is_a? Array
        return(optdef.first.class.name.downcase + "s") if !optdef.empty?
        if opttype
          raise ArgumentError.new("multiple argument type must be plural") unless opttype.max_args > 1
          return nil
        else
          raise ArgumentError.new("multiple argument type cannot be deduced from an empty array")
        end
      end
      return disambiguated_default.class.name.downcase
    end

    def self.get_klass_from_default(opts, opttype)
      ## for options with :multi => true, an array default doesn't imply
      ## a multi-valued argument. for that you have to specify a :type
      ## as well. (this is how we disambiguate an ambiguous situation;
      ## see the docs for Parser#opt for details.)

      disambiguated_default = if opts[:multi] && opts[:default].is_a?(Array) && opttype.nil?
                                opts[:default].first
                              else
                                opts[:default]
                              end

      return nil if disambiguated_default.nil?
      type_from_default = get_type_from_disdef(opts[:default], opttype, disambiguated_default)
      return Optimist::Parser.registry_getopttype(type_from_default)
    end

    #private_class_method :get_type_from_disdef
    #private_class_method :get_klass_from_default

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

  # Flag option.  Has no arguments. Can be negated with "no-".
  class BooleanOption < Option

    def initialize(name, desc, default : Bool?)
      super
      @default = default.nil? ? false : default
      @min_args = 0
      @max_args = 0
    end
    
    def parse(_paramlist, neg_given)
      return(self.name.to_s =~ /^no_/ ? neg_given : !neg_given)
    end
  end

  # Floating point number option class.
  class FloatOption < Option
    def initialize(name, desc, default : Float64?)
      super
      @default = default
    end
    
    def type_format ; "=<f>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map do |pg|
        pg.map do |param|
          unless param =~ FLOAT_RE
            raise CommandlineError.new("option '#{self.name}' needs a floating-point number")
          end
          param.to_f
        end
      end
    end
  end

  # Integer number option class.
  class IntOption < Option
    
    def initialize(name, desc, default : Int32?)
      super
      @default = default
    end
    
    def type_format ; "=<i>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map do |pg|
        pg.map do |param|
          unless param =~ /^-?[\d_]+$/
            raise CommandlineError.new("option '#{self.name}' needs an integer")
          end
          param.to_i
        end
      end
    end
  end

  # Option class for handling IO objects and URLs.
  # Note that this will return the file-handle, not the file-name
  # in the case of file-paths given to it.
  class IOOption < Option

    def type_format ; "=<filename/uri>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map do |pg|
        pg.map do |param|
          if param =~ /^(stdin|-)$/i
            STDIN
          else
            #require "open-uri"
            #begin
            #  open param
            #rescue SystemCallError => e
            #  raise CommandlineError, "file or url for option '#{self.name}' cannot be opened: #{e.message}"
            #end
            File.open(param)
          end
        end
      end
    end
  end

  # Option class for handling Strings.
  class StringOption < Option

    def type_format ; "=<s>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map { |pg| pg.map(&.to_s) }
    end
  end

  # 
  class StringFlagOption < StringOption

    def type_format ; "=<s?>" ; end
    def parse(paramlist, neg_given)
      paramlist.map do |plist|
        plist.map do |pg|
          neg_given ? false : pg
          #case pg
          #when FalseClass then () ? neg_given : !neg_given
          #when TrueClass then (self.name.to_s =~ /^no_/) ? neg_given : !neg_given
          #else pg
          #end
        end
      end
    end

    def initialize(name, desc, default : Bool?)
      super
      @default = default.nil? ? false : default
      @min_args = 0
      @max_args = 1
    end
    
    def compatible_with?(other_option)
      selftype = typeof(self)
      selftype == typeof(other_option) ||
        typeof(other_option) == BooleanOption ||
        typeof(other_option) == StringArrayOption
    end

  end


  class DateOption < Option

    def type_format ; "=<date>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map do |pg|
        pg.map do |param|
          if param.is_a?(Time)
            param
          elsif param.is_a?(String)
            Time.parse!(param, "%Y-%m-%d")
          else
            raise CommandlineError.new("option '#{self.name}' needs a date")
          end
        end
      end
    end
  end

  ### MULTI_OPT_TYPES :
  ## The set of values that indicate a multiple-parameter option (i.e., that
  ## takes multiple space-separated values on the commandline) when passed as
  ## the +:type+ parameter of #opt.

  # Option class for handling multiple Integers
  class IntArrayOption < IntOption
    def type_format ; "=<i+>" ; end
    #def initialize ; super ; @max_args = 999 ; end
  end

  # Option class for handling multiple Floats
  class FloatArrayOption < FloatOption
    def type_format ; "=<f+>" ; end
    #def initialize ; super ; @max_args = 999 ; end
  end

  # Option class for handling multiple Strings
  class StringArrayOption < StringOption
    def type_format ; "=<s+>" ; end
    #def initialize ; super ; @max_args = 999 ; end
  end

  # Option class for handling multiple dates
  class DateArrayOption < DateOption
    def type_format ; "=<date+>" ; end
    #def initialize ; super ; @max_args = 999 ; end
  end

  # Option class for handling Files/URLs via 'open'
  class IOArrayOption < IOOption
    def type_format ; "=<filename/uri+>" ; end
    #def initialize(name ; super ; @max_args = 999 ; end
  end

end
