module Optimist
  # # Regex for integer numbers
  INT_RE = /^-?[\d_]+$/

  # # Regex for floating point numbers
  FLOAT_RE = /^-?((\d+(\.\d+)?)|(\.\d+))([eE][-+]?[\d]+)?$/

  # # Regex for parameters
  PARAM_RE = /^-(-|\.$|[^\d\.])/

  # # The easy, syntactic-sugary entry method into Optimist. Creates a Parser,
  # # passes the block to it, then parses +args+ with it, handling any errors or
  # # requests for help or version information appropriately (and then exiting).
  # # Modifies +args+ in place. Returns a hash of option values.
  ##
  # # The block passed in should contain zero or more calls to `opt`
  # # (Parser#opt), zero or more calls to +text+ (Parser#text), and
  # # probably a call to +version+ (Parser#version).
  ##
  # # The returned block contains a value for every option specified with
  # # `opt`.  The value will be the value given on the commandline, or the
  # # default value if the option was not specified on the commandline. For
  # # every option specified on the commandline, a key "<option
  # # name>_given" will also be set in the hash.
  ##
  # # Example:
  ##
  # #   require 'optimist'
  # #   opts = Optimist::options do
  # #     opt :monkey, "Use monkey mode"                 # a flag --monkey, defaulting to false
  # #     opt :name, "Monkey name", cls: StringOpt       # a string --name <s>, defaulting to nil
  # #     opt :num_limbs, "Number of limbs", default: 4  # an integer --num-limbs <i>, defaulting to 4
  # #   end
  ##
  # #   ## if called with no arguments
  # #   p opts # => {:monkey=>false, :name=>nil, :num_limbs=>4, :help=>false}
  ##
  # #   ## if called with --monkey
  # #   p opts # => {:monkey=>true, :name=>nil, :num_limbs=>4, :help=>false, :monkey_given=>true}
  ##
  # # Settings:
  # #   Optimist::options and Optimist::Parser.new accept +settings+ to control how
  # #   options are interpreted.  These settings are given as hash arguments, e.g:
  ##
  # #   opts = Optimist::options(args: ARGV, inexact_match: true) do
  # #     opt :foobar, 'messed up'
  # #     opt :forget, 'forget it'
  # #   end
  ##
  # #  **settings** include:
  # #  + `exact_match` : If `false`, allows a minimum unambigous number of characters to match a long option.  If `true`, requires all characters of the long option to be give.  Defaults to `false`.
  # #  + `suggestions` : If true, enables suggestions when unknown arguments are given.  Defaults to `true`.
  # #  + `explicit_short_options` : If `true`, Short options will only be created where explicitly defined.  If you do not like short-options, this will prevent having to define `short: false` for all of your options.  Defaults to `false`.

  # Internally, we create SystemExit exceptions and then finally
  # call `exit`.  This variable can disable the final `exit` to let the `SystemExit` so that we can capture it in our test suite.

  @@real_exit = true

  # If we ever create a parser, then call Optimist.die external to the
  # parser, then we use this var to know what the last parser was.
  # Feels like something we ought to get rid of...

  @@last_parser : Parser? = nil

  # Enable/disable real system exit at the class level
  def self.disable_exit
    @@real_exit = false
  end

  def self.enable_exit
    @@real_exit = true
  end

  def self.options(args : Array(String) = ARGV,
                   stdout : IO = STDOUT,
                   stderr : IO = STDERR,
                   **kwargs,
                   &block)
    parser = Parser.new(**kwargs)
    @@last_parser = parser
    with parser yield

    begin
      self.with_standard_exception_handling(parser, stdout: stdout, stderr: stderr) do
        parser.parse args
      end
    rescue ex : SystemExit
      if @@real_exit
        exit ex.error_code
      else
        raise ex # re-raise
      end
    end
  end

  # # If Optimist.options doesn't do quite what you want, you can create a Parser
  # # object and call Parser#parse on it. That method will throw CommandlineError,
  # # HelpNeeded and VersionNeeded exceptions when necessary; if you want to
  # # have these handled for you in the standard manner (e.g. show the help
  # # and then exit upon an HelpNeeded exception), call your code from within
  # # a block passed to this method.
  ##
  # # Note that this method will raise SystemExit after handling an exception!
  ##
  # # Usage example:
  ##
  # #   require 'optimist'
  # #   par = Optimist::Parser.new do
  # #     opt :monkey, "Use monkey mode"                  # a flag --monkey, defaulting to false
  # #     opt :goat, "Use goat mode", default: true       # a flag --goat, defaulting to true
  # #   end
  ##
  # #   opts = Optimist.with_standard_exception_handling par do
  # #     o = par.parse ARGV
  # #     raise Optimist::HelpNeeded if ARGV.empty? # show help screen
  # #     o
  # #   end
  ##
  # # Requires passing in the parser object.

  def self.with_standard_exception_handling(parser : Parser, stdout : IO = STDOUT, stderr : IO = STDERR)
    yield
  rescue ex : CommandlineError
    parser.die(ex.message, nil, ex.error_code, stderr: stderr)
  rescue ex : HelpNeeded
    ex.parser.educate(stdout)
    raise SystemExit.new
  rescue VersionNeeded
    stdout.puts parser.version
    raise SystemExit.new
  end

  # # Informs the user that their usage of 'arg' was wrong, as detailed by
  # # 'msg', and dies. Example:
  ##
  # #   options do
  # #     opt :volume, default: 0.0
  # #   end
  ##
  # #   die :volume, "too loud" if opts["volume"].value > 10.0
  # #   die :volume, "too soft" if opts["volume"].value < 0.1
  ##
  # # In the one-argument case, simply print that message, a notice
  # # about -h, and die. Example:
  ##
  # #   options do
  # #     opt :whatever # ...
  # #   end
  ##
  # #   Optimist.die "need at least one filename" if ARGV.empty?
  ##
  # # An exit code can be provide if needed
  ##
  # #   Optimist.die "need at least one filename", -2 if ARGV.empty?
  def self.die(arg, msg = nil, error_code = nil, stderr : IO = STDERR)
    if @@last_parser
      @@last_parser.as(Parser).die arg, msg, error_code, stderr: stderr
    else
      raise ArgumentError.new "Optimist.die can only be called after Optimist.options"
    end
  end

  # # Displays the help message and dies. Example:
  ##
  # #   options do
  # #     opt :volume, default: 0.0
  # #     banner <<-EOS
  # #   Usage:
  # #          #{PROGRAM_NAME} [options] <name>
  # #   where [options] are:
  # #   EOS
  # #   end
  ##
  # #   Optimist.educate if ARGV.empty?
  def self.educate(stream : IO = STDOUT)
    if @@last_parser
      @@last_parser.as(Parser).educate(stream)
      raise SystemExit.new
    else
      raise ArgumentError.new("Optimist::educate can only be called after Optimist::options")
    end
  end
end # module
