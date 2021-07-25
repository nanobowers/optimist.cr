module Optimist

  ## The commandline parser. In typical usage, the methods in this class
  ## will be handled internally by Optimist::options. In this case, only the
  ## #opt, #banner and #version, #depends, and #conflicts methods will
  ## typically be called.
  ##
  ## If you want to instantiate this class yourself (for more complicated
  ## argument-parsing logic), call #parse to actually produce the output hash,
  ## and consider calling it from within
  ## Optimist::with_standard_exception_handling.
  class Parser

    ## The values from the commandline that were not interpreted by #parse.
    getter :leftovers

    ## The complete configuration hashes for each option. (Mainly useful
    ## for testing.)
    getter :specs

    ## A flag that determines whether or not to raise an error if the parser is passed one or more
    ##  options that were not registered ahead of time.  If 'true', then the parser will simply
    ##  ignore options that it does not recognize.
    property :ignore_invalid_options

    
    DEFAULT_SETTINGS = { exact_match: false,
                         explicit_short_opts: false,
                         suggestions: true
                       }

    @synopsis : String?
    @usage : String?
    @version : String?
    #@settings : NamedTuple(Symbol, Bool)
    
    ## Initializes the parser, and instance-evaluates any block given.
    def initialize(*a)
      @version = nil
      @leftovers = [] of String
      @specs = {} of Symbol => Option
      @long = {} of String => String
      @short = {} of String => String
      @order = [] of String
      @constraints = [] of String
      @stop_words = [] of String
      @stop_on_unknown = false
      @educate_on_error = false
      @synopsis = nil
      @usage = nil
      @subcommand_parsers = {} of String => String #??
      #@settings = a
      
      ## allow passing settings through Parser.new as an optional hash.
      ## but keep compatibility with non-hashy args, though.
      #begin
      #  settings_hash = Hash[*a]
      #  @settings = DEFAULT_SETTINGS.merge(settings_hash)
      ### a=[] ## clear out args if using as settings-hash
      #rescue ArgumentError
      #  @settings = DEFAULT_SETTINGS
      #end

      # instance_eval(&b) if b # can't take arguments
      #cloaker(&b).bind(self).call(*a) if b
      #with self yield # self.instance_exec(*a, &b) if block_given?

      #NOTE# yield now happens externally..
      
    end

    ## Define an option. +name+ is the option name, a unique identifier
    ## for the option that you will use internally, which should be a
    ## symbol or a string. +desc+ is a string description which will be
    ## displayed in help messages.
    ##
    ## Takes the following optional arguments:
    ##
    ## [+:long+] Specify the long form of the argument, i.e. the form with two dashes. If unspecified, will be automatically derived based on the argument name by turning the +name+ option into a string, and replacing any _'s by -'s.
    ## [+:short+] Specify the short form of the argument, i.e. the form with one dash. If unspecified, will be automatically derived from +name+. Use :none: to not have a short value.
    ## [+:type+] Require that the argument take a parameter or parameters of type +type+. For a single parameter, the value can be a member of +SINGLE_ARG_TYPES+, or a corresponding Ruby class (e.g. +Integer+ for +:int+). For multiple-argument parameters, the value can be any member of +MULTI_ARG_TYPES+ constant. If unset, the default argument type is +:flag+, meaning that the argument does not take a parameter. The specification of +:type+ is not necessary if a +:default+ is given.
    ## [+:default+] Set the default value for an argument. Without a default value, the hash returned by #parse (and thus Optimist::options) will have a +nil+ value for this key unless the argument is given on the commandline. The argument type is derived automatically from the class of the default value given, so specifying a +:type+ is not necessary if a +:default+ is given. (But see below for an important caveat when +:multi+: is specified too.) If the argument is a flag, and the default is set to +true+, then if it is specified on the the commandline the value will be +false+.
    ## [+:required+] If set to +true+, the argument must be provided on the commandline.
    ## [+:multi+] If set to +true+, allows multiple occurrences of the option on the commandline. Otherwise, only a single instance of the option is allowed. (Note that this is different from taking multiple parameters. See below.)
    ##
    ## Note that there are two types of argument multiplicity: an argument
    ## can take multiple values, e.g. "--arg 1 2 3". An argument can also
    ## be allowed to occur multiple times, e.g. "--arg 1 --arg 2".
    ##
    ## Arguments that take multiple values should have a +:type+ parameter
    ## drawn from +MULTI_ARG_TYPES+ (e.g. +:strings+), or a +:default:+
    ## value of an array of the correct type (e.g. [String]). The
    ## value of this argument will be an array of the parameters on the
    ## commandline.
    ##
    ## Arguments that can occur multiple times should be marked with
    ## +:multi+ => +true+. The value of this argument will also be an array.
    ## In contrast with regular non-multi options, if not specified on
    ## the commandline, the default value will be [], not nil.
    ##
    ## These two attributes can be combined (e.g. +:type+ => +:strings+,
    ## +:multi+ => +true+), in which case the value of the argument will be
    ## an array of arrays.
    ##
    ## There's one ambiguous case to be aware of: when +:multi+: is true and a
    ## +:default+ is set to an array (of something), it's ambiguous whether this
    ## is a multi-value argument as well as a multi-occurrence argument.
    ## In thise case, Optimist assumes that it's not a multi-value argument.
    ## If you want a multi-value, multi-occurrence argument with a default
    ## value, you must specify +:type+ as well.

    # no-block case
    def opt(name, desc : String = "", **opts)
      opt(name, desc, **opts) { }
    end

    def opt(name, desc : String = "", **opts, &b)
      #@myopts = opts
      #opts[:callback] = b
      #opts[:desc] = desc

      o = Option.create(name, desc, **opts)

      raise ArgumentError, "you already have an argument named '#{name}'" if @specs.member? o.name
      o.long.names.each do |lng|
        raise ArgumentError, "long option name #{lng.inspect} is already taken; please specify a (different) :long/:alt" if @long[lng]
        @long[lng] = o.name
      end

      raise ArgumentError, "permitted values for option #{o.long.long.inspect} must be either nil, Range, Regexp or an Array;" unless o.permitted_type_valid?

      o.short.chars.each do |short|
        raise ArgumentError, "short option name #{short.inspect} is already taken; please specify a (different) :short" if @short[short]
        @short[short] = o.name
      end

      @specs[o.name] = o
      @order << [:opt, o.name]
    end

    def subcmd(name, desc=nil, **args, &b)
      sc = SubcommandParser.new(name, desc, **args, &b)
      @subcommand_parsers[name.to_sym] = sc
      return sc
    end

    ## Sets the version string. If set, the user can request the version
    ## on the commandline. Should probably be of the form "<program name>
    ## <version number>".
    property :version

    ## Sets the usage string. If set the message will be printed as the
    ## first line in the help (educate) output and ending in two new
    ## lines.
    property :usage

    ## Adds a synopsis (command summary description) right below the
    ## usage line, or as the first line if usage isn't specified.
    property :synopsys

    ## Adds text to the help display. Can be interspersed with calls to
    ## #opt to build a multi-section help page.
    def banner(s)
      @order << [:text, s]
    end

    #DEAD# alias_method :text, :banner

    ## Marks two (or more!) options as requiring each other. Only handles
    ## undirected (i.e., mutual) dependencies. Directed dependencies are
    ## better modeled with Optimist::die.
    def depends(*syms)
      syms.each { |sym| raise ArgumentError, "unknown option '#{sym}'" unless @specs[sym] }
      @constraints << [:depends, syms]
    end

    ## Marks two (or more!) options as conflicting.
    def conflicts(*syms)
      syms.each { |sym| raise ArgumentError, "unknown option '#{sym}'" unless @specs[sym] }
      @constraints << [:conflicts, syms]
    end

    ## Defines a set of words which cause parsing to terminate when
    ## encountered, such that any options to the left of the word are
    ## parsed as usual, and options to the right of the word are left
    ## intact.
    ##
    ## A typical use case would be for subcommand support, where these
    ## would be set to the list of subcommands. A subsequent Optimist
    ## invocation would then be used to parse subcommand options, after
    ## shifting the subcommand off of ARGV.
    def stop_on(*words)
      @stop_words = words.flatten
    end

    ## Similar to #stop_on, but stops on any unknown word when encountered
    ## (unless it is a parameter for an argument). This is useful for
    ## cases where you don't know the set of subcommands ahead of time,
    ## i.e., without first parsing the global options.
    def stop_on_unknown
      @stop_on_unknown = true
    end

    ## Instead of displaying "Try --help for help." on an error
    ## display the usage (via educate)
    def educate_on_error
      @educate_on_error = true
    end

    ## Match long variables with inexact match.
    ## If we hit a complete match, then use that, otherwise see how many long-options partially match.
    ## If only one partially matches, then we can safely use that.
    ## Otherwise, we raise an error that the partially given option was ambiguous.
    private def perform_inexact_match(arg, partial_match)  # :nodoc:
      return @long[partial_match] if @long.has_key?(partial_match)
      partially_matched_keys = @long.keys.grep(/^#{partial_match}/)
      return case partially_matched_keys.size
             when 0 ; nil
             when 1 ; @long[partially_matched_keys.first]
             else ; raise CommandlineError, "ambiguous option '#{arg}' matched keys (#{partially_matched_keys.join(',')})"
             end
    end

    private def handle_unknown_argument(arg, candidates, suggestions)
      errstring = "unknown argument '#{arg}'"
      errstring += " for command '#{subcommand_name}'" if self.respond_to?(:subcommand_name)
      if suggestions
        input = arg.sub(/^[-]*/,"")

        # Code borrowed from did_you_mean gem
        jw_threshold = 0.75
        seed = candidates.select {|candidate| DidYouMean::JaroWinkler.distance(candidate, input) >= jw_threshold } \
               .sort_by! {|candidate| DidYouMean::JaroWinkler.distance(candidate.to_s, input) } \
               .reverse!
        # Correct mistypes
        threshold   = (input.length * 0.25).ceil
        has_mistype = seed.rindex {|c| DidYouMean::Levenshtein.distance(c, input) <= threshold }
        corrections = if has_mistype
                        seed.take(has_mistype + 1)
                      else
                        # Correct misspells
                        seed.select do |candidate|
                          length    = input.length < candidate.length ? input.length : candidate.length

                          DidYouMean::Levenshtein.distance(candidate, input) < length
                        end.first(1)
                      end
        unless corrections.empty?
          dashdash_corrections = corrections.map{|s| "--#{s}" }
          errstring << ".  Did you mean: [#{dashdash_corrections.join(", ")}] ?"
        end
      end
      raise CommandlineError, errstring
    end

    # Provide a list of given subcommands.
    # List will be empty if subcmd was never given.
    def subcommands : Array(String)
      @subcommand_parsers.keys
    end

    ## Parses the commandline. Typically called by Optimist::options,
    ## but you can call it directly if you need more control.
    ##
    ## throws CommandlineError, HelpNeeded, and VersionNeeded exceptions.
    def parse(cmdline = ARGV)
      if subcommands.empty?
        parse_base(cmdline)
      else
        # set state for subcommand-parse
        @stop_words += subcommands
        @stop_on_unknown = true
        # parse global options
        global_result = parse_base(cmdline)
        # grab subcommand
        cmd = cmdline.shift
        raise CommandlineError.new("no subcommand provided") unless cmd
        # parse subcommand options
        subcmd_parser = @subcommand_parsers[cmd.to_sym]
        raise CommandlineError.new("unknown subcommand '#{cmd}'") unless subcmd_parser
        subcmd_result = subcmd_parser.parse_base(cmdline)
        SubcommandResult.new(subcommand: cmd,
                             global_options: global_result,
                             subcommand_options: subcmd_result,
                             leftovers: subcmd_parser.leftovers)
      end
    end
    
    def parse_base(cmdline = ARGV)
      vals = {} of Symbol => (String | Array(String))
      required = {} of Symbol => String

      # create default version/help options if not already defined
      opt :version, "Print version and exit" if @version && ! (@specs[:version] || @long["version"])
      opt :help, "Show this message" unless @specs[:help] || @long["help"]

      @specs.each do |sym, opts|
        required[sym] = true if opts.required?
        vals[sym] = opts.default
        vals[sym] = [] of String if opts.multi && !opts.default # multi arguments default to [], not nil
      end

      resolve_default_short_options! unless @settings[:explicit_short_opts]

      ## resolve symbols
      given_args = {} of Symbol => String
      @leftovers = each_arg cmdline do |original_arg, params|
        ## handle --no- forms
        arg, negative_given = if original_arg =~ /^--no-([^-]\S*)$/
                                ["--#{$1}", true]
                              else
                                [original_arg, false]
                              end

        sym = case arg
              when /^-([^-])$/      then @short[$1]
              when /^--([^-]\S*)$/  then @long[$1] || @long["no-#{$1}"]
              else                       raise CommandlineError, "invalid argument syntax: '#{arg}'"
              end

        if arg =~ /--no-/ # explicitly invalidate --no-no- arguments
          sym = nil 
        elsif !sym && !@settings[:exact_match] && arg.match(/^--(\S*)$/)
          # If sym is not already found in the short/long lookup then 
          # support inexact matching of long-arguments like perl's Getopt::Long
          sym = perform_inexact_match(arg, $1)
        end
        
        next nil if ignore_invalid_options && !sym
        
        handle_unknown_argument(arg, @long.keys, @settings[:suggestions]) unless sym

        if given_args.includes?(sym) && !@specs[sym].multi?
          raise CommandlineError, "option '#{arg}' specified multiple times"
        end

        given_args[sym] ||= {} of Symbol => Bool
        given_args[sym][:arg] = arg
        given_args[sym][:negative_given] = negative_given
        given_args[sym][:params] ||= [] of String

        # The block returns the number of parameters taken.
        num_params_taken = 0

        #DEBUG# puts "\nparams:#{params} npt:#{num_params_taken},ps:#{params.size}"

        #if params.size > 0
        #  if @specs[sym].min_args == 1 && @specs[sym].max_args == 1
        #    given_args[sym][:params] << params[0, 1]  # take the first parameter
        #    num_params_taken = 1
        #  elsif @specs[sym].max_args > 1
        #    given_args[sym][:params] << params        # take all the parameters
        #    num_params_taken = params.size
        #  end
        #end

        if params.size == 0
          if @specs[sym].min_args == 0
            given_args[sym][:params] << [ @specs[sym].default || true]
          end
        elsif params.size > 0
          if params.size >= @specs[sym].max_args
            # take smaller of the two sizes to determine how many parameters to take
            num_params_taken = [params.size, @specs[sym].max_args].min
            given_args[sym][:params] << params[0, num_params_taken]
          else
            # take all the parameters
            given_args[sym][:params] << params        
            num_params_taken = params.size
          end
        end
        

        num_params_taken
      end

      ## check for version and help args, and raise if set.
      ## HelpNeeded should pass the parser object so we know how to educate
      ## if we are in a global-command or subcommand
      raise VersionNeeded if given_args.includes? :version
      raise HelpNeeded.new(nil, parser: self) if given_args.includes? :help

      ## check constraint satisfaction
      @constraints.each do |xtype, syms|
        constraint_sym = syms.find { |sym| given_args[sym] }
        next unless constraint_sym
        
        case xtype
        when :depends
          syms.each { |sym| raise CommandlineError, "--#{@specs[constraint_sym].long} requires --#{@specs[sym].long}" unless given_args.includes? sym }
        when :conflicts
          syms.each { |sym| raise CommandlineError, "--#{@specs[constraint_sym].long} conflicts with --#{@specs[sym].long}" if given_args.includes?(sym) && (sym != constraint_sym) }
        end
      end

      required.each do |sym, _val|
        raise CommandlineError, "option --#{@specs[sym].long} must be specified" unless given_args.includes? sym
      end

      ## parse parameters
      given_args.each do |sym, given_data|
        arg, params, negative_given = given_data.values_at :arg, :params, :negative_given

        opts = @specs[sym]

        if params.size < opts.min_args
          raise CommandlineError, "option '#{arg}' needs a parameter" unless opts.default
          params << (opts.array_default? ? opts.default.clone : [opts.default])
        end

        if params.first && opts.permitted
          params.first.each do |val|
            opts.validate_permitted(arg, val)
          end
        end

        vals["#{sym}_given".intern] = true # mark argument as specified on the commandline

        vals[sym] = opts.parse(params, negative_given)

        if opts.min_args==0 && opts.max_args==1
          if opts.multi?
            vals[sym] = vals[sym].map { |p| p[0] }
          else
            vals[sym] = vals[sym][0][0]
          end
        elsif opts.min_args==1 && opts.max_args==1
          if opts.multi?        # multiple options, each with a single parameter
            vals[sym] = vals[sym].map { |p| p[0] }
          else                  # single parameter
            vals[sym] = vals[sym][0][0]
          end
        elsif opts.max_args>1 && !opts.multi?
          vals[sym] = vals[sym][0]  # single option, with multiple parameters
        end
        # else: multiple options, with multiple parameters

        opts.callback.call(vals[sym]) if opts.callback
      end

      ## modify input in place with only those
      ## arguments we didn't process
      cmdline.clear
      @leftovers.each { |l| cmdline << l }

      ## allow openstruct-style accessors
      #class << vals
      #  def method_missing(m, *_args)
      #    self[m] || self[m.to_s]
      #  end
      #end
      vals
    end

    # Create default text banner in a string so we can override it
    # in the SubcommandParser class.
    def default_banner
      command_name = File.basename($0).gsub(/\.[^.]+$/, "")
      bannertext = ""
      bannertext << "Usage: #{command_name} #{@usage}\n" if @usage
      bannertext << "#{@synopsis}\n" if @synopsis
      bannertext << "\n" if @usage || @synopsis
      bannertext << "#{@version}\n" if @version
      unless subcommands.empty?
        bannertext << "\n" if @version   
        bannertext << "Commands:\n"
        @subcommand_parsers.each_value do |scmd|
          bannertext << sprintf("  %-20s %s\n", scmd.name, scmd.desc)
        end
        bannertext << "\n"   
      end
      bannertext << "Options:\n"
      return bannertext
    end

    
    ## Print the help message to +stream+.
    def educate(stream = STDOUT)
      # hack: calculate it now; otherwise we have to be careful not to
      # call this unless the cursor's at the beginning of a line.
      width(stream)

      left = {} of String => String
      @specs.each { |name, spec| left[name] = spec.educate }

      leftcol_width = left.values.map(&:length).max || 0
      rightcol_start = leftcol_width + 6 # spaces

      # print a default banner here if there is no text/banner
      unless @order.size > 0 && @order.first.first == :text
        stream.puts default_banner()
      end

      @order.each do |what, opt|
        if what == :text
          # print text/banner here
          stream.puts wrap(opt)
          next
        end

        spec = @specs[opt]
        stream.printf "  %-#{leftcol_width}s    ", left[opt]
        desc = spec.full_description

        stream.puts wrap(desc, width: width - rightcol_start - 1, prefix: rightcol_start)
      end
    end

    def width(iostream) #:nodoc:
      #    @width ||= if iostream.tty?
      #      begin
      #        require 'io/console'
      #        w = IO.console.winsize.last
      #        w.to_i > 0 ? w : 80
      #      rescue LoadError, NoMethodError, Errno::ENOTTY, Errno::EBADF, Errno::EINV#AL
      #        legacy_width
      #      end
      #    else
      #      80
      #    end
      @width = 80
    end

    private def legacy_width
      # Support for older Rubies where io/console is not available
      `tput cols`.to_i
    rescue Errno::ENOENT
      80
    end

    def wrap(str, width : Int32, prefix : Int32) # :nodoc:
      if str == ""
        [""]
      else
        inner = false
        str.split("\n").map do |s|
          line = wrap_line(s, prefix: prefix, width: width, inner: inner)
          inner = true
          line
        end.flatten
      end
    end

    ## The per-parser version of Optimist::die (see that for documentation).
    def die(arg, msg = nil, error_code = nil)
      msg, error_code = nil, msg if msg.kind_of?(Integer)
      if msg
        STDERR.puts "Error: argument --#{@specs[arg].long} #{msg}."
      else
        STDERR.puts "Error: #{arg}."
      end
      if @educate_on_error
        STDERR.puts
        educate STDERR
      else
        STDERR.puts "Try --help for help."
      end
      exit(error_code || -1)
    end

    ## yield successive arg, parameter pairs
    private def each_arg(args : String)
      remains = [] of String
      i = 0

      until i >= args.length
        return remains += args[i..-1] if @stop_words.member? args[i]
        case args[i]
        when /^--$/ # arg terminator
          return remains += args[(i + 1)..-1]
        when /^--(\S+?)=(.*)$/ # long argument with equals
          num_params_taken = yield "--#{$1}", [$2]
          if num_params_taken.nil?
            remains << args[i]
            if @stop_on_unknown
              return remains += args[i + 1..-1]
            end
          end
          i += 1
        when /^--(\S+)$/ # long argument
          params = collect_argument_parameters(args, i + 1)
          num_params_taken = yield args[i], params

          if num_params_taken.nil?
            remains << args[i]
            if @stop_on_unknown
              return remains += args[i + 1..-1]
            end
          else
            i += num_params_taken
          end
          i += 1
        when /^-(\S+)$/ # one or more short arguments
          short_remaining = ""
          shortargs = $1.split(//)
          shortargs.each_with_index do |a, j|
            if j == (shortargs.length - 1)
              params = collect_argument_parameters(args, i + 1)

              num_params_taken = yield "-#{a}", params
              unless num_params_taken
                short_remaining << a
                if @stop_on_unknown
                  remains << "-#{short_remaining}"
                  return remains += args[i + 1..-1]
                end
              else
                i += num_params_taken
              end
            else
              unless yield "-#{a}", [] of String
                short_remaining << a
                if @stop_on_unknown
                  short_remaining += shortargs[j + 1..-1].join
                  remains << "-#{short_remaining}"
                  return remains += args[i + 1..-1]
                end
              end
            end
          end

          unless short_remaining.empty?
            remains << "-#{short_remaining}"
          end
          i += 1
        else
          if @stop_on_unknown
            return remains += args[i..-1]
          else
            remains << args[i]
            i += 1
          end
        end
      end

      remains
    end

    def collect_argument_parameters(args, start_at)
      params = [] of String
      pos = start_at
      while args[pos] && args[pos] !~ PARAM_RE && !@stop_words.member?(args[pos])
        params << args[pos]
        pos += 1
      end
      params
    end
    
    def resolve_default_short_options!
      @order.each do |xtype, name|
        opts = @specs[name]
        next if xtype != :opt || opts.doesnt_need_autogen_short

        c = opts.long.long.split(//).find { |d| d !~ Optimist::ShortNames::INVALID_ARG_REGEX && !@short.member?(d) }
        if c # found a character to use
          opts.short.add c
          @short[c] = name
        end
      end
    end

    private def wrap_line(str, width : Int32, prefix : Int32 = 0, inner : Bool = false)
      localwidth = width || (self.width - 1)
      start = 0
      ret = [] of String
      until start > str.length
        nextt =
          if start + localwidth >= str.length
            str.length
          else
            x = str.rindex(/\s/, start + localwidth)
            x = str.index(/\s/, start) if x && x < start
            x || str.length
          end
        ret << ((ret.empty? && !inner) ? "" : " " * prefix) + str[start...nextt]
        start = nextt + 1
      end
      ret
    end

    ## instance_eval but with ability to handle block arguments
    ## thanks to _why: http://redhanded.hobix.com/inspect/aBlockCostume.html
    #def cloaker(&b)
    #  (class << self; self; end).class_eval do
    #    define_method :cloaker_, &b
    #    meth = instance_method :cloaker_
    #    remove_method :cloaker_
    #    meth
    #  end
    #end
  end

  # If used with subcommands, then return this object instead of a Hash.
  class SubcommandResult
    def initialize(subcommand : Symbol? = nil,
                   global_options : Hash(String,String) = {} of String => String,
                                                                subcommand_options : Hash(String,String) = {} of String => String,
                                                                                                                 leftovers : Array(String) = [] of String)
      @subcommand = subcommand
      @global_options = global_options
      @subcommand_options = subcommand_options
      @leftovers = leftovers
    end
    property :subcommand, :global_options, :subcommand_options, :leftovers
  end

  class SubcommandParser < Parser
    getter :name, :desc
    def initialize(name, desc, *a, &b)
      super(a, &b)
      @name = name
      @desc = desc
    end

    # alias to make referencing more obvious.
    def subcommand_name
      @name
    end
    
    def default_banner()
      command_name = File.basename($0).gsub(/\.[^.]+$/, "")
      bannertext = ""
      bannertext << "Usage: #{command_name} #{@name} #{@usage}\n\n" if @usage
      bannertext << "#{@synopsis}\n\n" if @synopsis
      bannertext << "#{desc}\n\n" if @desc
      bannertext << "Options:\n"
      return bannertext
    end

  end

  
end