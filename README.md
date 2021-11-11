# Optimist

Optimist is an option parser that "just gets out of your way".


## Description

Optimist is a commandline option parser that just gets out of your way.
One line of code per option is all you need to write. For that, you get a nice
automatically-generated help page, robust option parsing, and sensible defaults
for everything you don't specify.

This code is a crystal rewrite and feature improved version of the rubygem: https://github.com/ManageIQ/optimist

## Features

- Simple usage.
- Sensible defaults. Usually no tweaking necessary, much tweaking possible.
- Support for long and short options (*but not Git style subcommands*)
- Type validation and  conversion.
- Automatic help message generation, wrapped to current screen width.

See the **Extended Features** section below for the differences/enhancements

## Usage

Code example:

```crystal
require "optimist"

opts = Optimist.options do
  opt :monkey, "Use monkey mode"                     # flag --monkey, default false
  opt :name, "Monkey name", cls: Optimist::StringOpt # string --name <s>, default nil
  opt :num_limbs, "Number of limbs", default: 4      # integer --num-limbs <i>, default to 4
end

opts.each { |k, v| p [k, v.value, v.given?] }
```

Example - not setting any command-line options:

```
$ crystal examples/a_basic_example.cr
["monkey", false, false]
["name", nil, false]
["num_limbs", 4, false]
["help", false, false]
```

Example - setting some command-line options:
```
$ crystal examples/a_basic_example.cr -m --num 5
["monkey", true, true]
["name", nil, false]
["num_limbs", 5, true]
["help", false, false]

```

Example - using `-h` (help)
```
$ crystal examples/a_basic_example.cr -h
Options:
  -m, --monkey           Use monkey mode
  -n, --name=<s>         Monkey name
  -u, --num-limbs=<i>    Number of limbs (Default: 4)
  -h, --help             Show this message
```

See more examples in the [examples directory](examples/)

## Main Interface / Basic Features
+ Automatically creates a -h/--help option and basic help message
+ `banner` command to add/write arbitrary text/banners for usage messages.
+ `version` command to set version and create a -v option
+ `opt` command that creates options (`opt` keyword args follow)
   + `require:` - the option is required
   + `cls:` - class of this option.  Can be an type derived from `Optimist::Option` or one of a few basic types (e.g. `String`, `Bool`, `Int32`, etc.)
   + `default:` - a default value.  If `cls:` is not provided, the class will be derived from the default.
   + `permitted:` - a list of permitted values, a range or regex to limit.
   + `long` - long-name, if not the name of the option.
   + `short` - one or more short-flags.  Can be numeric.
   + Using the option will either set the `value` and `given` fields of the option, or otherwise call a block argument (callback) if it exists.
+ `conflicts`/`depends` to prevent/require some options be used in conjunction with others

## Differences with the Ruby version

+ The `type:` keyword argument for `opt` was changed to `cls:` to prevent conflicting with a Crystal reserved word
+ The return type of `Optimist.options` is a Hash of String -> Option.  Because the values may be any subclass of `Option`, it will probably be necessary to recast the Option with `.as()`.
+ The `text` alias for `banner` was removed.


## Extended features unavailable in the original Optimist rubygem

### Parser Settings
- Automatic suggestions whens incorrect options are given
    - disable with `suggestions: false`
    - see example below
- Inexact matching of long arguments
    - disable with `exact_match: true`
    - see example below
- Available prevention of short-arguments by default
    - enable with `explicit_short_opts: true`

### Option Settings

#### Permitted

Permitted options allow specifying valid choices for an option using lists, ranges or regexp's 
- `permitted:` to specify a allow lists, ranges or regexp filtering of options.
- `permitted_response:` can be added to provide more explicit output when incorrect choices are given.
- see [example](examples/permitted.rb)
- concept and code via @akhoury6

#### Alternate named options

Short options can now take be provided as an Array of list of alternate short-option characters.
- `opt :cat, 'desc', short: ['c', 't']`
- Previously `short:` only accepted a single character.

Long options can be given alternate names using `alt:`
- `opt :length, 'desc', alt: ['size']`
- Note that `long: 'othername'` still exists to _override_ the named option and can be used in addition to the alt names.

See [example](examples/alt_names.rb)

### Stringflag option-type

It is useful to allow an option that can be set as a string, used with a default string or unset, especialy in the case of specifying a log-file using this usage model:
```
$ toolname               # no logging
$ toolname --log         # enable logging with a default logfile name
$ toolname --log my.log  # enable logging to my.log
```

AFAICT this was not possible with the original Optimist.  This can be set using `cls: Optimist::StringFlagOpt`

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     optimist:
       github: nanobowers/optimist
   ```

2. Run `shards install`


## Contributing

1. Fork it (<https://github.com/your-github-user/optimist/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ben Bowers](https://github.com/your-github-user) - creator and maintainer
