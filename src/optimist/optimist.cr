module Optimist

  ## Regex for integer numbers
  INT_RE = /^-?[\d_]+$/
  
  ## Regex for floating point numbers
  FLOAT_RE = /^-?((\d+(\.\d+)?)|(\.\d+))([eE][-+]?[\d]+)?$/
  
  ## Regex for parameters
  PARAM_RE = /^-(-|\.$|[^\d\.])/
  

## The easy, syntactic-sugary entry method into Optimist. Creates a Parser,
## passes the block to it, then parses +args+ with it, handling any errors or
## requests for help or version information appropriately (and then exiting).
## Modifies +args+ in place. Returns a hash of option values.
##
## The block passed in should contain zero or more calls to +opt+
## (Parser#opt), zero or more calls to +text+ (Parser#text), and
## probably a call to +version+ (Parser#version).
##
## The returned block contains a value for every option specified with
## +opt+.  The value will be the value given on the commandline, or the
## default value if the option was not specified on the commandline. For
## every option specified on the commandline, a key "<option
## name>_given" will also be set in the hash.
##
## Example:
##
##   require 'optimist'
##   opts = Optimist::options do
##     opt :monkey, "Use monkey mode"                    # a flag --monkey, defaulting to false
##     opt :name, "Monkey name", :type => :string        # a string --name <s>, defaulting to nil
##     opt :num_limbs, "Number of limbs", :default => 4  # an integer --num-limbs <i>, defaulting to 4
##   end
##
##   ## if called with no arguments
##   p opts # => {:monkey=>false, :name=>nil, :num_limbs=>4, :help=>false}
##
##   ## if called with --monkey
##   p opts # => {:monkey=>true, :name=>nil, :num_limbs=>4, :help=>false, :monkey_given=>true}
##
## Settings:
##   Optimist::options and Optimist::Parser.new accept +settings+ to control how
##   options are interpreted.  These settings are given as hash arguments, e.g:
##
##   opts = Optimist::options(args: ARGV, inexact_match: true) do
##     opt :foobar, 'messed up'
##     opt :forget, 'forget it'
##   end
##
##  +settings+ include:
##  * :inexact_match  : Allow minimum unambigous number of characters to match a long option
##  * :suggestions    : Enables suggestions when unknown arguments are given
##  * :explicit_short : Short options will only be created where explicitly defined.  If you do not like short-options, this will prevent having to define :short: nil for all of your options.

  
  @@last_parser = Parser.new

def self.options(args : Array(String) = ARGV, **a, &block)
  #@@last_parser = Parser.new(**a) do
  #  block
  #end
  parser = Parser.new(**a)
  @@last_parser = parser
  with parser yield
  
  self.with_standard_exception_handling(parser) { parser.parse args }
end

## If Optimist::options doesn't do quite what you want, you can create a Parser
## object and call Parser#parse on it. That method will throw CommandlineError,
## HelpNeeded and VersionNeeded exceptions when necessary; if you want to
## have these handled for you in the standard manner (e.g. show the help
## and then exit upon an HelpNeeded exception), call your code from within
## a block passed to this method.
##
## Note that this method will call System#exit after handling an exception!
##
## Usage example:
##
##   require 'optimist'
##   p = Optimist::Parser.new do
##     opt :monkey, "Use monkey mode"                     # a flag --monkey, defaulting to false
##     opt :goat, "Use goat mode", :default => true       # a flag --goat, defaulting to true
##   end
##
##   opts = Optimist::with_standard_exception_handling p do
##     o = p.parse ARGV
##     raise Optimist::HelpNeeded if ARGV.empty? # show help screen
##     o
##   end
##
## Requires passing in the parser object.

def self.with_standard_exception_handling(parser : Parser)
  yield
rescue ex : CommandlineError
  parser.die(ex.message, nil, ex.error_code)
rescue ex : HelpNeeded
  ex.parser.educate
  exit
rescue VersionNeeded
  puts parser.version
  exit
end

## Informs the user that their usage of 'arg' was wrong, as detailed by
## 'msg', and dies. Example:
##
##   options do
##     opt :volume, :default => 0.0
##   end
##
##   die :volume, "too loud" if opts[:volume] > 10.0
##   die :volume, "too soft" if opts[:volume] < 0.1
##
## In the one-argument case, simply print that message, a notice
## about -h, and die. Example:
##
##   options do
##     opt :whatever # ...
##   end
##
##   Optimist::die "need at least one filename" if ARGV.empty?
##
## An exit code can be provide if needed
##
##   Optimist::die "need at least one filename", -2 if ARGV.empty?
def self.die(arg, msg = nil, error_code = nil)
  if @@last_parser
    @@last_parser.die arg, msg, error_code
  else
    raise ArgumentError.new "Optimist::die can only be called after Optimist::options"
  end
end

## Displays the help message and dies. Example:
##
##   options do
##     opt :volume, :default => 0.0
##     banner <<-EOS
##   Usage:
##          #$0 [options] <name>
##   where [options] are:
##   EOS
##   end
##
##   Optimist::educate if ARGV.empty?
def self.educate
  if @@last_parser
    @@last_parser.educate
    exit
  else
    raise ArgumentError.new("Optimist::educate can only be called after Optimist::options")
  end
end


end # module
