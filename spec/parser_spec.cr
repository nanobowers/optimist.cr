require "./spec_helper"

include Optimist

describe Optimist::Parser do
  parser = Optimist::Parser.new

  Spec.before_each do
    parser = Optimist::Parser.new
  end

  it "has a version" do
    parser.version.should be_nil
    parser.version "optimist 5.2.3"
    parser.version.should eq "optimist 5.2.3"
  end

  it "has a usage" do
    parser.usage.should be nil
    parser.usage "usage string"
    parser.usage.should eq "usage string"
  end

  it "has a synopsis" do
    parser.synopsis.should be_nil
    parser.synopsis "synopsis string"
    parser.synopsis.should eq "synopsis string"
  end

  # def test_depends
  # def test_conflicts
  # def test_stop_on
  # def test_stop_on_unknown

  # die
  # def test_die_educate_on_error

  it "handles unknown arguments" do
    expect_raises(CommandlineError, /Unknown argument '--arg'/) {
      parser.parse(%w(--arg))
    }
    parser.opt :arg
    parser.parse(%w(--arg))
    err = expect_raises(CommandlineError, /Unknown argument '--arg2'/) {
      parser.parse(%w(--arg2))
    }
  end

  it "tests_unknown_arguments_with_suggestions" do
    sugp = Parser.new(suggestions: true)
    err = expect_raises(CommandlineError, /Unknown argument '--bone'/) {
      sugp.parse(%w(--bone))
    }

    sugp.opt :cone
    sugp.parse(%w(--cone))

    # single letter mismatch
    msg = /Unknown argument '--bone'.\s+Did you mean: \[--cone\]/
    expect_raises(CommandlineError, msg) { sugp.parse(%w(--bone)) }

    # transposition
    msg = /Unknown argument '--ocne'.\s+Did you mean: \[--cone\]/
    expect_raises(CommandlineError, msg) { sugp.parse(%w(--ocne)) }

    # extra letter at end
    msg = /Unknown argument '--cones'.\s+Did you mean: \[--cone\]/
    expect_raises(CommandlineError, msg) { sugp.parse(%w(--cones)) }

    # too big of a mismatch to suggest (extra letters in front)
    msg = /Unknown argument '--snowcone'/
    err = expect_raises(CommandlineError, msg) { sugp.parse(%w(--snowcone)) }

    # too big of a mismatch to suggest (nothing close)
    msg = /Unknown argument '--clown-nose'/
    expect_raises(CommandlineError, msg) { sugp.parse(%w(--clown-nose)) }

    sugp.opt :zippy
    sugp.opt :zapzy
    # single letter mismatch, matches two
    msg = /Unknown argument '--zipzy'.\s+Did you mean: \[--zapzy, --zippy\]/
    expect_raises(CommandlineError, msg) { sugp.parse(%w(--zipzy)) }

    sugp.opt :big_bug
    # suggest common case of dash versus underscore in argnames
    msg = /Unknown argument '--big_bug'.\s+Did you mean: \[--big-bug\]/
    expect_raises(CommandlineError, msg) { sugp.parse(%w(--big_bug)) }
  end

  it "correctly handles leading dashes" do
    parser.opt :arg
    parser.parse(%w(--arg))
    parser.parse(%w(arg))
    expect_raises(CommandlineError) { parser.parse(%w(---arg)) }
    expect_raises(CommandlineError) { parser.parse(%w(-arg)) }
  end

  describe "required" do
    it "errors when not given" do
      parser.opt :arg, "desc", required: true
      parser.opt :arg2, "desc", required: false
      parser.opt :arg3, "desc", required: false

      parser.parse(%w(--arg))
      parser.parse(%w(--arg --arg2))
      expect_raises(CommandlineError) { parser.parse(%w(--arg2)) }
      expect_raises(CommandlineError) { parser.parse(%w(--arg2 --arg3)) }
    end

    it "accuses correctly when two-given and one-missing" do
      parser.opt :arg1, "desc1", required: true
      parser.opt :arg2, "desc2", required: true
      expect_raises(CommandlineError, /arg2/) { parser.parse(%w(--arg1)) }
      expect_raises(CommandlineError, /arg1/) { parser.parse(%w(--arg2)) }
      parser.parse(%w(--arg1 --arg2))
    end
  end

  # Allows stdlib type defaults
  it "allows stdlib types as the cls:" do
    parser.opt :aa, "desc", cls: Int32
    parser.opt :bb, "desc", cls: String
    parser.opt :cc, "desc", cls: Float64
    parser.opt :dd, "desc", cls: Bool
    opts = parser.parse(%w(--aa 9 --bb hello --dd --cc -9.12))
    opts["aa"].value.should eq 9
    opts["bb"].value.should eq "hello"
    opts["cc"].value.should eq -9.12
    opts["dd"].value.should eq true
  end

  # flags that take an argument error unless given one
  it "tests_argflags_demand_args" do
    parser.opt :goodarg, "desc", cls: StringOpt
    parser.opt :goodarg2, "desc", cls: StringOpt

    parser.parse(%w(--goodarg goat))
    expect_raises(CommandlineError) { parser.parse(%w(--goodarg --goodarg2 goat)) }
    expect_raises(CommandlineError) { parser.parse(%w(--goodarg)) }
  end

  # flags that don't take arguments ignore them
  it "tests_arglessflags_refuse_args" do
    parser.opt :goodarg, ""
    parser.opt :goodarg2, ""
    parser.parse(%w(--goodarg))
    parser.parse(%w(--goodarg --goodarg2))
    opts = parser.parse %w(--goodarg a)
    opts["goodarg"].value.should eq true
    parser.leftovers.should eq ["a"]
  end

  # flags that require args of a specific type refuse args of other
  # types
  it "tests_typed_args_refuse_args_of_other_types" do
    parser.opt :goodarg, "desc", cls: Int32Opt
    # expect_raises(ArgumentError) { parser.opt :badarg, "desc", cls: :asdf }

    parser.parse(%w(--goodarg 3))
    expect_raises(CommandlineError) { parser.parse(%w(--goodarg 4.2)) }
    expect_raises(CommandlineError) { parser.parse(%w(--goodarg hello)) }
  end

  # type is correctly derived from :default
  it "tests_type_correctly_derived_from_default" do
    # single arg: int
    parser.opt :argsi, "desc", default: 0
    opts = parser.parse(%w(--))
    opts["argsi"].value.should eq 0
    opts = parser.parse(%w(--argsi 4))
    opts["argsi"].value.should eq 4
    opts = parser.parse(%w(--argsi=4))
    opts["argsi"].value.should eq 4
    opts = parser.parse(%w(--argsi=-4))
    opts["argsi"].value.should eq -4

    expect_raises(CommandlineError) { parser.parse(%w(--argsi 4.2)) }
    expect_raises(CommandlineError) { parser.parse(%w(--argsi hello)) }

    # single arg: float
    parser.opt :argsf, "desc", default: 3.14
    opts = parser.parse(%w(--))
    opts["argsf"].value.should eq 3.14
    opts = parser.parse(%w(--argsf 2.41))
    opts["argsf"].value.should eq 2.41
    opts = parser.parse(%w(--argsf 2))
    opts["argsf"].value.should eq 2
    opts = parser.parse(%w(--argsf 1.0e-2))
    opts["argsf"].value.should eq 1.0e-2
    expect_raises(CommandlineError) { parser.parse(%w(--argsf hello)) }

    # single arg: string
    parser.opt :argss, "desc", default: "foobar"
    opts = parser.parse(%w(--))
    opts["argss"].value.should eq "foobar"
    opts = parser.parse(%w(--argss 2.41))
    opts["argss"].value.should eq "2.41"
    opts = parser.parse(%w(--argss hello))
    opts["argss"].value.should eq "hello"

    #    # multi args: ints
    #    parser.opt :argmi, "desc", default: [3, 5]
    #    opts = parser.parse(%w(--))
    #    opts[:argmi].value.should eq [3, 5]
    #    opts = parser.parse(%w(--argmi 4))
    #    opts[:argmi].value.should eq [4]
    #    expect_raises(CommandlineError) { parser.parse(%w(--argmi 4.2)) }
    #    expect_raises(CommandlineError) { parser.parse(%w(--argmi hello)) }
    #
    #    # multi args: floats
    #    parser.opt :argmf, "desc", default: [3.34, 5.21]
    #    opts = parser.parse(%w(--))
    #    opts[:argmf].value.should eq [3.34, 5.21]
    #    opts = parser.parse(%w(--argmf 2))
    #    opts[:argmf].value.should eq [2]
    #    opts = parser.parse(%w(--argmf 4.0))
    #    opts[:argmf].value.should eq [4.0]
    #    expect_raises(CommandlineError) { parser.parse(%w(--argmf hello)) }
    #
    #    # multi args: dates
    #    dates = [Date.today, Date.civil(2007, 1, 4)]
    #    parser.opt :argmd, "desc", default: dates
    #    opts = parser.parse(%w(--))
    #    opts[:argmd].value.should eq dates
    #    opts = parser.parse(["--argmd", "Jan 4, 2007"])
    #    opts[:argmd].value.should eq [Date.civil(2007, 1, 4)]
    #    expect_raises(CommandlineError) { parser.parse(%w(--argmd hello)) }
    #
    #    # multi args: strings
    #    parser.opt :argmst, "desc", default: %w(hello world)
    #    opts = parser.parse(%w(--))
    #    opts[:argmst].value.should eq %w(hello world)
    #    opts = parser.parse(%w(--argmst 3.4))
    #    opts[:argmst].value.should eq ["3.4"]
    #    opts = parser.parse(%w(--argmst goodbye))
    #    opts[:argmst].value.should eq ["goodbye"]
  end

  # cls: and default: must match if both are specified
  # Cannot test mismatch of cls: and default: in crystal because it is a compiler error.

  it "creates an opt with matching cls: and default:" do
    parser.opt :argsi, "desc", cls: Int32Opt, default: 4
    parser.opt :argsf, "desc", cls: Float64Opt, default: 3.14
    parser.opt :argss, "desc", cls: StringOpt, default: "yo"
    parser.opt :argmi, "desc", cls: Int32ArrayOpt, default: [4]
    parser.opt :argmf, "desc", cls: Float64ArrayOpt, default: [3.14]
    parser.opt :argmst, "desc", cls: StringArrayOpt, default: ["yo"]
  end

  ##

  describe "StringFlagOpt" do
    it "sets gets defaults and non-default values" do
      parser.opt :argd, "desc", default: "default_string", cls: StringFlagOpt

      opts = parser.parse(%w(--))
      opts["argd"].given?.should be_false
      opts["argd"].value.should eq "default_string"

      opts = parser.parse(%w(--argd))
      opts["argd"].given?.should be_true
      opts["argd"].value.should eq "default_string"

      opts = parser.parse(%w(--argd different_string))
      opts["argd"].given?.should be_true
      opts["argd"].value.should eq "different_string"
    end
  end

  it "tests ArrayOpts with empty array defaults" do
    parser.opt :argmi, "desc", cls: Int32ArrayOpt, default: [] of Int32
    parser.opt :argmf, "desc", cls: Float64ArrayOpt, default: [] of Float64
    parser.opt :argms, "desc", cls: StringArrayOpt, default: [] of String

    opts = parser.parse([] of String)
    opts["argmi"].value.should eq [] of Int32
    opts["argmf"].value.should eq [] of Float64
    opts["argms"].value.should eq [] of String
  end

  it "tests_long_detects_bad_names" do
    parser.opt :goodarg, "desc", long: "none"
    parser.opt :goodarg2, "desc", long: "--two"
    expect_raises(ArgumentError) { parser.opt :badarg, "desc", long: "" }
    expect_raises(ArgumentError) { parser.opt :badarg2, "desc", long: "--" }
    expect_raises(ArgumentError) { parser.opt :badarg3, "desc", long: "-one" }
    expect_raises(ArgumentError) { parser.opt :badarg4, "desc", long: "---toomany" }
  end

  describe "short" do
    it "detects bad names" do
      parser.opt :goodarg, "desc", short: "a"
      parser.opt :goodarg2, "desc", short: "-b"
      expect_raises(ArgumentError) { parser.opt :badarg, "desc", short: "" }
      expect_raises(ArgumentError) { parser.opt :badarg2, "desc", short: "-ab" }
      expect_raises(ArgumentError) { parser.opt :badarg3, "desc", short: "--t" }
    end

    it "disables when false" do
      parser.opt :arg, "desc", short: false
      parser.parse([] of String)
      sio = IO::Memory.new
      parser.educate sio
      sio.to_s.should match(/--arg\s+desc/)
      expect_raises(CommandlineError, /Unknown argument/) { parser.parse %w(-a) }
    end

    describe "auto-creation" do
      it "creates" do
        parser.opt :arg
        parser.opt :arg2
        parser.opt :arg3
        opts = parser.parse %w(-a -g)
        opts["arg"].value.should eq true
        opts["arg2"].value.should eq false
        opts["arg3"].value.should eq true
      end

      it "skips_dashes_and_numbers" do
        parser.opt :arg        # auto: a
        parser.opt :arg_potato # auto: r
        parser.opt :arg_muffin # auto: g
        parser.opt :arg_daisy  # auto: d (not _)!
        parser.opt :arg_r2d2f  # auto: f (not 2)!

        opts = parser.parse %w(-f -d)
        opts["arg_daisy"].value.should eq true
        opts["arg_r2d2f"].value.should eq true
        opts["arg"].value.should eq false
        opts["arg_potato"].value.should eq false
        opts["arg_muffin"].value.should eq false

        opts["arg"].short.chars.should eq ["a"]
        opts["arg_potato"].short.chars.should eq ["r"]
        opts["arg_muffin"].short.chars.should eq ["g"]
        opts["arg_daisy"].short.chars.should eq ["d"]
        opts["arg_r2d2f"].short.chars.should eq ["f"]
      end

      it "is ok with running out of chars" do
        parser.opt :arg1 # auto: a
        parser.opt :arg2 # auto: r
        parser.opt :arg3 # auto: g
        parser.opt :arg4 # auto: uh oh!
        opts = parser.parse([] of String)
        opts["arg4"].short.chars.should be_empty
      end

      it "can be disabled for the whole parser" do
        newp = Parser.new(explicit_short_options: true)
        newp.opt :user1, "user1"
        newp.opt :bag, "bag", short: 'b'
        expect_raises(CommandlineError) do
          newp.parse %w(-u)
        end
        opts = newp.parse %w(--user1)
        opts["user1"].value.should eq true
        opts = newp.parse %w(-b)
        opts["bag"].value.should eq true
      end
      it "assigns after user shorts" do
        parser.opt :aab, "b_opt" # should be assigned to -b
        parser.opt :ccd, "d_opt" # should be assigned to -d
        parser.opt :user1, "user1", short: 'a'
        parser.opt :user2, "user2", short: 'c'

        opts = parser.parse %w(-a -b)
        opts["user1"].value.should eq true
        opts["user2"].value.should eq false
        opts["aab"].value.should eq true
        opts["ccd"].value.should eq false

        opts = parser.parse %w(-c -d)
        opts["user1"].value.should eq false
        opts["user2"].value.should eq true
        opts["aab"].value.should eq false
        opts["ccd"].value.should eq true
      end
    end
  end

  # two args can't have the same name
  it "ensures conflicting names are detected" do
    parser.opt :goodarg
    expect_raises(ArgumentError) { parser.opt :goodarg }
  end

  # two args can't have the same :long
  it "tests_conflicting_longs_detected" do
    parser.opt :goodarg, "desc", long: "--goodarg"
    expect_raises(ArgumentError) { parser.opt :badarg, "desc", long: "--goodarg" }
  end

  # two args can't have the same :short
  it "tests_conflicting_shorts_detected" do
    parser.opt :goodarg, "desc", short: "-g"
    expect_raises(ArgumentError) { parser.opt :badarg, "desc", short: "-g" }
  end

  # note: this behavior has changed in optimist 2.0!
  it "tests_flag_parameters" do
    parser.opt :defaultnone, "desc"
    parser.opt :defaultfalse, "desc", default: false
    parser.opt :defaulttrue, "desc", default: true

    # default state
    opts = parser.parse([] of String)
    opts["defaultnone"].value.should eq false
    opts["defaultfalse"].value.should eq false
    opts["defaulttrue"].value.should eq true

    # specifying turns them on, regardless of default
    opts = parser.parse %w(--defaultfalse --defaulttrue --defaultnone)
    opts["defaultnone"].value.should eq true
    opts["defaultfalse"].value.should eq true
    opts["defaulttrue"].value.should eq true

    # using --no- form turns them off, regardless of default
    opts = parser.parse %w(--no-defaultfalse --no-defaulttrue --no-defaultnone)
    opts["defaultnone"].value.should eq false
    opts["defaultfalse"].value.should eq false
    opts["defaulttrue"].value.should eq false
  end

  it "tests_flag_parameters_for_inverted_flags" do
    parser.opt :no_default_none, "desc"
    parser.opt :no_default_false, "desc", default: false
    parser.opt :no_default_true, "desc", default: true

    # default state
    opts = parser.parse([] of String)

    opts["no_default_none"].value.should eq false
    opts["no_default_false"].value.should eq false
    opts["no_default_true"].value.should eq true

    # specifying turns them all on, regardless of default
    opts = parser.parse %w(--no-default-false --no-default-true --no-default-none)
    opts["no_default_none"].value.should eq true
    opts["no_default_false"].value.should eq true
    opts["no_default_true"].value.should eq true

    # using dropped-no form turns them all off, regardless of default
    opts = parser.parse %w(--default-false --default-true --default-none)
    opts["no_default_none"].value.should eq false
    opts["no_default_false"].value.should eq false
    opts["no_default_true"].value.should eq false

    # disallow double negatives for reasons of sanity preservation
    expect_raises(CommandlineError) { parser.parse %w(--no-no-default-true) }
  end

  it "tests_short_options_combine" do
    parser.opt :arg1, "desc", short: "a"
    parser.opt :arg2, "desc", short: "b"
    parser.opt :arg3, "desc", short: "c", cls: Int32Opt

    opts = parser.parse %w(-a -b)
    opts["arg1"].value.should eq true
    opts["arg2"].value.should eq true
    opts["arg3"].value.should be_nil

    opts = parser.parse %w(-ab)
    opts["arg1"].value.should eq true
    opts["arg2"].value.should eq true
    opts["arg3"].value.should be_nil

    opts = parser.parse %w(-ac 4 -b)
    opts["arg1"].value.should eq true
    opts["arg2"].value.should eq true
    opts["arg3"].value.should eq 4

    expect_raises(CommandlineError) { parser.parse %w(-cab 4) }
    expect_raises(CommandlineError) { parser.parse %w(-cba 4) }
  end

  it "tests_doubledash_ends_option_processing" do
    parser.opt :arg1, "desc", short: "a", default: 0
    parser.opt :arg2, "desc", short: "b", default: 0
    opts = parser.parse %w(-- -a 3 -b 2)
    opts["arg1"].value.should eq 0
    opts["arg2"].value.should eq 0
    parser.leftovers.should eq %w(-a 3 -b 2)

    opts = parser.parse %w(-a 3 -- -b 2)
    opts["arg1"].value.should eq 3
    opts["arg2"].value.should eq 0
    parser.leftovers.should eq %w(-b 2)

    opts = parser.parse %w(-a 3 -b 2 --)
    opts["arg1"].value.should eq 3
    opts["arg2"].value.should eq 2
    parser.leftovers.should eq %w()
  end

  it "tests_wrap" do
    parser.wrap("").should eq [""]
    parser.wrap("a").should eq ["a"]
    parser.wrap("one two three", width: 8).should eq ["one two", "three"]
    parser.wrap("one two three", width: 80).should eq ["one two three"]
    parser.wrap("one two three", width: 3).should eq ["one", "two", "three"]
    parser.wrap("onetwothree", width: 3).should eq ["onetwothree"]

    output = parser.wrap(<<-EOM, width: 100)
Test is an awesome program that does something very, very important.

Usage:
  test [options] <filenames>+
where [options] are:
EOM
    output.should eq [
      "Test is an awesome program that does something very, very important.",
      "",
      "Usage:",
      "  test [options] <filenames>+",
      "where [options] are:",
    ]
  end

  it "tests_multi_line_description" do
    strio = IO::Memory.new

    desc = <<-EOM
    This is an arg
    with a multi-line description
    EOM

    parser.opt :arg, desc, cls: Int32Opt

    parser.educate(strio)

    strio.to_s.chomp.should eq <<-EOM
    Options:
      --arg=<i>    This is an arg
                   with a multi-line description
    EOM
  end

  it "tests_integer_formatting" do
    parser.opt :int, "desc", cls: Int32Opt, short: "i"
    opts = parser.parse %w(-i 5)
    opts["int"].value.should eq 5
    expect_raises(CommandlineError) { parser.parse %w(-i a) }
    expect_raises(CommandlineError) { parser.parse %w(-i 1a) }
    expect_raises(CommandlineError) { parser.parse %w(-i a1) }
    expect_raises(CommandlineError) { parser.parse %w(-i +11) }
    expect_raises(CommandlineError) { parser.parse %w(-i 1.0) }
    expect_raises(CommandlineError) { parser.parse %w(-i 1z1) }
    expect_raises(CommandlineError) { parser.parse %w(-i -42.0) }
    expect_raises(CommandlineError, /Must give an argument/) { parser.parse %w(-i) }
  end

  it "tests_floating_point_formatting" do
    parser.opt :arg, "desc", cls: Float64Opt, short: "f"
    opts = parser.parse %w(-f 1)
    opts["arg"].value.should eq 1.0
    opts = parser.parse %w(-f 1.0)
    opts["arg"].value.should eq 1.0
    opts = parser.parse %w(-f 0.1)
    opts["arg"].value.should eq 0.1
    opts = parser.parse %w(-f .1)
    opts["arg"].value.should eq 0.1
    opts = parser.parse %w(-f .99999999999999999999)
    opts["arg"].value.should eq 1.0
    opts = parser.parse %w(-f -1)
    opts["arg"].value.should eq -1.0
    opts = parser.parse %w(-f -1.0)
    opts["arg"].value.should eq -1.0
    opts = parser.parse %w(-f -0.1)
    opts["arg"].value.should eq -0.1
    opts = parser.parse %w(-f -.1)
    opts["arg"].value.should eq -0.1
    expect_raises(CommandlineError) { parser.parse %w(-f a) }
    expect_raises(CommandlineError) { parser.parse %w(-f 1a) }
    expect_raises(CommandlineError) { parser.parse %w(-f 1.a) }
    expect_raises(CommandlineError) { parser.parse %w(-f a.1) }
    expect_raises(CommandlineError) { parser.parse %w(-f 1.0.0) }
    expect_raises(CommandlineError) { parser.parse %w(-f .) }
    expect_raises(CommandlineError) { parser.parse %w(-f -.) }
    expect_raises(CommandlineError, /Must give an argument/) { parser.parse %w(-f) }
  end

  it "tests_short_options_cant_be_numeric" do
    expect_raises(ArgumentError) { parser.opt :arg, "desc", short: "-1" }
    parser.opt :a1b, "desc"
    parser.opt :a2b, "desc"
    parser.parse([] of String)
    # testing private interface to ensure default
    # short options did not become numeric
    parser.specs["a1b"].short.chars.first.should eq "a"
    parser.specs["a2b"].short.chars.first.should eq "b"
  end

  it "tests_short_options_can_be_weird" do
    parser.opt :arg1, "desc", short: "#"
    parser.opt :arg2, "desc", short: "."
    expect_raises(ArgumentError) { parser.opt :arg3, "desc", short: "-" }
  end

  it "tests_options_cant_be_set_multiple_times_if_not_specified" do
    parser.opt :arg, "desc", short: "-x"
    parser.parse %w(-x)
    expect_raises(CommandlineError) { parser.parse %w(-x -x) }
    expect_raises(CommandlineError) { parser.parse %w(-xx) }
  end

  it "tests_options_can_be_set_multiple_times_if_specified" do
    parser.opt :arg, "desc", short: "-x", multi: true
    parser.parse %w(-x)
    parser.parse %w(-x -x)
    parser.parse %w(-xx)
  end

  it "tests_short_options_with_multiple_options" do
    parser.opt :xarg, "desc", short: "-x", cls: StringArrayOpt
    opts = parser.parse %w(-x a -x b)
    opts["xarg"].value.should eq %w(a b)
    parser.leftovers.should be_empty
  end

  it "tests_short_options_with_multiple_options_does_not_affect_flags_type" do
    parser.opt :xarg, "desc", short: "-x", cls: BoolOpt, multi: true

    opts = parser.parse %w(-x a)
    opts["xarg"].value.should eq true
    parser.leftovers.should eq %w(a)

    opts = parser.parse %w(-x a -x b)
    opts["xarg"].value.should eq true
    parser.leftovers.should eq %w(a b)

    opts = parser.parse %w(-xx a -x b)
    opts["xarg"].value.should eq true
    parser.leftovers.should eq %w(a b)
  end

  describe "ArrayOpt" do
    it "allows multiple usage" do
      parser.opt :xarg, "desc", cls: Int32ArrayOpt
      opts = parser.parse %w(-x 3 -x 4 -x 0)
      opts["xarg"].value.should eq [3, 4, 0]
      parser.leftovers.should be_empty

      parser.opt :yarg, "desc", cls: Float64ArrayOpt
      opts = parser.parse %w(-y 3.14 -y 4.21 -y 0.66)
      opts["yarg"].value.should eq [3.14, 4.21, 0.66]
      parser.leftovers.should be_empty

      parser.opt :zarg, "desc", cls: StringArrayOpt
      opts = parser.parse %w(-z a -z b -z c)
      opts["zarg"].value.should eq %w(a b c)
      parser.leftovers.should be_empty
    end

    it "combines short opts" do
      parser.opt :arg1, "desc", short: "a"
      parser.opt :arg2, "desc", short: "b"
      parser.opt :arg3, "desc", short: "c", cls: Int32ArrayOpt
      parser.opt :arg4, "desc", short: "d", cls: Float64ArrayOpt

      opts = parser.parse %w(-abc 4 -c 6 -c 9)
      opts["arg1"].value.should eq true
      opts["arg2"].value.should eq true
      opts["arg3"].value.should eq [4, 6, 9]

      opts = parser.parse %w(-ac 4 -c 6 -c 9 -bd 3.14 -d 2.41)
      opts["arg1"].value.should eq true
      opts["arg2"].value.should eq true
      opts["arg3"].value.should eq [4, 6, 9]
      opts["arg4"].value.should eq [3.14, 2.41]

      opts = parser.parse %w(-ac 3 -bd 1e-9)
      opts["arg1"].value.should eq true
      opts["arg2"].value.should eq true
      opts["arg3"].value.should eq [3]
      opts["arg4"].value.should eq [1e-9]
    end

    it "allows multiple long options" do
      parser.opt :xarg, "desc", cls: StringArrayOpt
      opts = parser.parse %w(--xarg=a --xarg=b)
      opts["xarg"].value.should eq %w(a b)
      parser.leftovers.should be_empty
      opts = parser.parse %w(--xarg a --xarg b)
      opts["xarg"].value.should eq %w(a b)
      parser.leftovers.should be_empty
    end

    it "tests_long_options_with_multiple_arguments" do
      parser.opt :xarg, "desc", cls: Int32ArrayOpt
      opts = parser.parse %w(--xarg 3 --xarg 2 --xarg 5)
      opts["xarg"].value.should eq [3, 2, 5]
      parser.leftovers.should be_empty

      opts = parser.parse %w(--xarg=3)
      opts["xarg"].value.should eq [3]
      parser.leftovers.should be_empty

      parser.opt :yarg, "desc", cls: Float64ArrayOpt
      opts = parser.parse %w(--yarg 3.14 --yarg 2.41 --yarg 5.66)
      opts["yarg"].value.should eq [3.14, 2.41, 5.66]
      parser.leftovers.should be_empty

      opts = parser.parse %w(--yarg=3.14)
      opts["yarg"].value.should eq [3.14]
      parser.leftovers.should be_empty

      parser.opt :zarg, "desc", cls: StringArrayOpt
      opts = parser.parse %w(--zarg a --zarg b --zarg=c)
      opts["zarg"].value.should eq %w(a b c)
      parser.leftovers.should be_empty

      opts = parser.parse %w(--zarg=a)
      opts["zarg"].value.should eq %w(a)
      parser.leftovers.should be_empty
    end
  end

  it "tests_long_options_also_take_equals" do
    parser.opt :arg, "desc", long: "arg", cls: StringOpt, default: "hello"
    opts = parser.parse %w()
    opts["arg"].value.should eq "hello"
    opts = parser.parse %w(--arg goat)
    opts["arg"].value.should eq "goat"
    opts = parser.parse %w(--arg=goat)
    opts["arg"].value.should eq "goat"
    # actually, this next one is valid. empty string for --arg, and goat as a
    # leftover.
    # expect_raises(CommandlineError) { opts = parser.parse %w(--arg= goat) }
  end

  describe "auto-generated long names" do
    it "converts underscores to hyphens" do
      parser.opt :hello_there
      parser.specs["hello_there"].long.long.should eq "hello-there"
    end
  end

  describe "version" do
    before_each do
      parser.opt :asdf, "desc", cls: StringOpt
      parser.version "version"
    end

    it "raises VersionNeeded" do
      expect_raises(VersionNeeded) { parser.parse %w(--version) }
      expect_raises(VersionNeeded) { parser.parse %w(--asdf abcd --version) }
      expect_raises(VersionNeeded) { parser.parse %w(--version --asdf abcd) }
    end

    it "allows some errors before VersionNeeded" do
      expect_raises(CommandlineError) { parser.parse %w(--asdf --version) }
      expect_raises(CommandlineError) { parser.parse %w(--version --asdf) }
    end
  end

  describe "help" do
    before_each do
      parser.opt :asdf, "desc", cls: StringOpt
    end

    it "raises HelpNeeded" do
      expect_raises(HelpNeeded) { parser.parse %w(--help) }
      expect_raises(HelpNeeded) { parser.parse %w(-h) }
      expect_raises(HelpNeeded) { parser.parse %w(--help --asdf zzz) }
      expect_raises(HelpNeeded) { parser.parse %w(-h -a zzz) }
      expect_raises(HelpNeeded) { parser.parse %w(--asdf abc --help) }
      expect_raises(HelpNeeded) { parser.parse %w(--asdf ghi -h) }
    end
    it "allows some errors before HelpNeeded" do
      expect_raises(CommandlineError) { parser.parse %w(--asdf) }
      expect_raises(CommandlineError) { parser.parse %w(--asdf --help) }
      expect_raises(CommandlineError) { parser.parse %w(--asdf -h) }
    end
  end

  describe "constraints" do
    it "can conflict" do
      parser.opt :one
      expect_raises(ArgumentError) { parser.conflicts :one, :two }
      parser.opt :two
      parser.conflicts :one, :two
      parser.parse %w(--one)
      parser.parse %w(--two)
      expect_raises(CommandlineError) { parser.parse %w(--one --two) }

      parser.opt :hello
      parser.opt :yellow
      parser.opt :mellow
      parser.opt :jello
      parser.conflicts :hello, :yellow, :mellow, :jello
      expect_raises(CommandlineError) { parser.parse %w(--hello --yellow --mellow --jello) }
      expect_raises(CommandlineError) { parser.parse %w(--hello --mellow --jello) }
      expect_raises(CommandlineError) { parser.parse %w(--hello --jello) }

      parser.parse %w(--hello)
      parser.parse %w(--jello)
      parser.parse %w(--yellow)
      parser.parse %w(--mellow)

      parser.parse %w(--mellow --one)
      parser.parse %w(--mellow --two)

      expect_raises(CommandlineError) { parser.parse %w(--mellow --two --jello) }
      expect_raises(CommandlineError) { parser.parse %w(--one --mellow --two --jello) }
    end

    it "errors when conflict not satisfied" do
      parser.opt :one
      parser.opt :two
      parser.conflicts :one, :two

      expect_raises(CommandlineError, /--one.*--two/) {
        parser.parse %w(--one --two)
      }
    end

    it "can depend" do
      parser.opt :one
      expect_raises(ArgumentError) { parser.depends :one, :two }
      parser.opt :two
      parser.depends :one, :two
      parser.parse %w(--one --two)
      expect_raises(CommandlineError) { parser.parse %w(--one) }
      expect_raises(CommandlineError) { parser.parse %w(--two) }

      parser.opt :hello
      parser.opt :yellow
      parser.opt :mellow
      parser.opt :jello
      parser.depends :hello, :yellow, :mellow, :jello
      parser.parse %w(--hello --yellow --mellow --jello)
      expect_raises(CommandlineError) { parser.parse %w(--hello --mellow --jello) }
      expect_raises(CommandlineError) { parser.parse %w(--hello --jello) }

      expect_raises(CommandlineError) { parser.parse %w(--hello) }
      expect_raises(CommandlineError) { parser.parse %w(--mellow) }

      parser.parse %w(--hello --yellow --mellow --jello --one --two)
      parser.parse %w(--hello --yellow --mellow --jello --one --two a b c)

      expect_raises(CommandlineError) { parser.parse %w(--mellow --two --jello --one) }
    end

    it "errors when depend not satisfied" do
      parser.opt :one
      parser.opt :two
      parser.depends :one, :two

      parser.parse %w(--one --two)

      expect_raises(CommandlineError, /--one requires --two/) { parser.parse %w(--one) }
      expect_raises(CommandlineError, /--two requires --one/) { parser.parse %w(--two) }
    end
  end

  describe "stopwords" do
    it "accepts them in the middle" do
      parser.opt :arg1, default: false
      parser.opt :arg2, default: false
      parser.stop_on %w(happy sad)

      opts = parser.parse %w(--arg1 happy --arg2)
      opts["arg1"].value.should eq true
      opts["arg2"].value.should eq false

      # restart parsing
      parser.leftovers.shift
      opts = parser.parse parser.leftovers
      opts["arg1"].value.should eq false
      opts["arg2"].value.should eq true
    end

    it "handles no stopwords" do
      parser.opt :arg1, default: false
      parser.opt :arg2, default: false
      parser.stop_on %w(happy sad)

      opts = parser.parse %w(--arg1 --arg2)
      opts["arg1"].value.should eq true
      opts["arg2"].value.should eq true

      # restart parsing
      parser.leftovers.should be_empty

      # parser.leftovers.shift
      opts = parser.parse parser.leftovers
      opts["arg1"].value.should eq false
      opts["arg2"].value.should eq false
    end

    it "handles multiple" do
      parser.opt :arg1, default: false
      parser.opt :arg2, default: false
      parser.stop_on %w(happy sad)

      opts = parser.parse %w(happy sad --arg1 --arg2)
      opts["arg1"].value.should eq false
      opts["arg2"].value.should eq false

      # restart parsing
      parser.leftovers.shift
      opts = parser.parse parser.leftovers
      opts["arg1"].value.should eq false
      opts["arg2"].value.should eq false

      # restart parsing again
      parser.leftovers.shift
      opts = parser.parse parser.leftovers
      opts["arg1"].value.should eq true
      opts["arg2"].value.should eq true
    end

    it "accepts short_args" do
      parser.opt :global_option, "This is a global option", short: "-g"
      parser.stop_on %w(sub-command-1 sub-command-2)

      global_opts = parser.parse %w(-g sub-command-1 -c)
      cmd = parser.leftovers.shift

      qqq = Parser.new
      qqq.opt :cmd_option, "This is an option only for the subcommand", short: "-c"
      cmd_opts = qqq.parse parser.leftovers

      global_opts["global_option"].value.should eq true
      global_opts["cmd_option"]?.should be_nil

      cmd_opts["cmd_option"].value.should eq true
      cmd_opts["global_option"]?.should be_nil

      cmd.should eq "sub-command-1"
      qqq.leftovers.should be_empty
    end
  end

  it "tests_alternate_args" do
    args = %w(-a -b -c)

    opts = ::Optimist.options(args) do
      opt :alpher, "Ralph Alpher", short: "-a"
      opt :bethe, "Hans Bethe", short: "-b"
      opt :gamow, "George Gamow", short: "-c"
    end

    physicists_with_humor = ["alpher", "bethe", "gamow"]
    physicists_with_humor.each do |physicist|
      opts[physicist].value.should eq true
    end
  end

  it "tests_io_arg_type" do
    parser.opt :arg, "desc", cls: FileOpt
    parser.opt :arg2, "desc", cls: FileOpt
    parser.opt :arg3, "desc", default: STDOUT

    opts = parser.parse([] of String)
    opts["arg3"].value.should eq STDOUT

    opts = parser.parse %w(--arg /dev/null)
    opts["arg"].value.should be_a File

    # TODO opts["arg"].path.should eq "/dev/null"

    # TODO: move to mocks
    # opts = parser.parse %w(--arg2 http://google.com/)
    # assert_kind_of StringIO, opts["arg2"].value

    opts = parser.parse %w(--arg3 stdin)
    opts["arg3"].value.should eq STDIN

    expect_raises(CommandlineError) { opts = parser.parse %w(--arg /fdasfasef/fessafef/asdfasdfa/fesasf) }
  end

  describe "multi-arg defaults" do
    it "tests StringArrayOpt" do
      parser.opt :arg2, "desc", default: ["hello"]
      opts = parser.parse([] of String)
      opts["arg2"].value.should eq ["hello"]

      opts = parser.parse %w(--arg2 hi)
      opts["arg2"].value.should eq ["hi"]

      opts = parser.parse %w(--arg2 hi --arg2 bye)
      opts["arg2"].value.should eq ["hi", "bye"]
    end
  end

  describe "given" do
    it "sets given for arg1 only" do
      parser.opt :arg1
      parser.opt :arg2
      opts = parser.parse %w(--arg1)
      opts["arg1"].given?.should eq true
      opts["arg2"].given?.should eq false
    end
    it "sets given for arg2 only" do
      parser.opt :arg1
      parser.opt :arg2
      opts = parser.parse %w(--arg2)
      opts["arg1"].given?.should eq false
      opts["arg2"].given?.should eq true
    end
    it "sets given for neither opt" do
      parser.opt :arg1
      parser.opt :arg2
      opts = parser.parse([] of String)
      opts["arg1"].given?.should eq false
      opts["arg2"].given?.should eq false
    end
    it "sets given for both opts" do
      parser.opt :arg1
      parser.opt :arg2
      opts = parser.parse %w(--arg1 --arg2)
      opts["arg1"].given?.should eq true
      opts["arg2"].given?.should eq true
    end
  end

  it "tests_inexact_match" do
    newp = Parser.new
    newp.opt :liberation, "liberate something", cls: Int32Opt
    newp.opt :evaluate, "evaluate something", cls: StringOpt
    opts = newp.parse %w(--lib 5 --ev bar)
    opts["liberation"].value.should eq 5
    opts["evaluate"].value.should eq "bar"
    opts["eval"]?.should be_nil
  end

  it "tests_exact_match" do
    newp = Parser.new(exact_match: true)
    newp.opt :liberation, "liberate something", cls: Int32Opt
    newp.opt :evaluate, "evaluate something", cls: StringOpt
    expect_raises(CommandlineError, /Unknown argument '--lib'/) do
      newp.parse %w(--lib 5)
    end
    expect_raises(CommandlineError, /Unknown argument '--ev'/) do
      newp.parse %w(--ev bar)
    end
  end

  it "tests_inexact_collision" do
    newp = Parser.new
    newp.opt :bookname, "name of a book", cls: StringOpt
    newp.opt :bookcost, "cost of the book", cls: StringOpt
    opts = newp.parse %w(--bookn hairy_potsworth --bookc 10)
    opts["bookname"].value.should eq "hairy_potsworth"
    opts["bookcost"].value.should eq "10"
    expect_raises(CommandlineError) do
      newp.parse %w(--book 5) # ambiguous
    end
    # partial match causes 'specified multiple times' error
    expect_raises(CommandlineError, /specified multiple times/) do
      newp.parse %w(--bookc 17 --bookcost 22)
    end
  end

  it "tests_inexact_collision_with_exact" do
    newp = Parser.new(exact_match: false)
    newp.opt :book, "name of a book", cls: StringOpt, default: "ABC"
    newp.opt :bookcost, "cost of the book", cls: Int32Opt, default: 5
    opts = newp.parse %w(--book warthog --bookc 3)
    opts["book"].value.should eq "warthog"
    opts["bookcost"].value.should eq 3
  end

  it "tests_accepts_arguments_with_spaces" do
    parser.opt :arg1, "arg", cls: StringOpt
    parser.opt :arg2, "arg2", cls: StringOpt

    opts = parser.parse ["--arg1", "hello there", "--arg2=hello there"]
    opts["arg1"].value.should eq "hello there"
    opts["arg2"].value.should eq "hello there"
    parser.leftovers.size.should eq 0
  end

  describe "Simple-Interface" do
    it "handles help" do
      sio = IO::Memory.new
      expect_raises(SystemExit) do
        Optimist.options(%w(-h), stdout: sio) do
          opt :potato
        end
      end
      sio.to_s.should match /Options:/

      # ensure regular status is returned
      ex = expect_raises(SystemExit) do
        Optimist.options(%w(-h), stdout: sio) do
          opt :potato
        end
      end
      ex.error_code.should eq 0
    end

    it "produces a version" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.options(%w(-v), stdout: sio) do
          version "1.2"
          opt :potato
        end
      end
      ex.error_code.should eq 0
      sio.to_s.should match /1.2/mi
    end

    it "handles regular usage" do
      sio = IO::Memory.new
      opts = Optimist.options(%w(--potato), stdout: sio) do
        opt :potato
      end
      opts["potato"].value.should eq true
    end

    it "handles die" do
      sio = IO::Memory.new
      opts = Optimist.options(%w(--potato)) do
        opt :potato
      end
      expect_raises(SystemExit) {
        Optimist.die(:potato, "is invalid", stderr: sio)
      }
      sio.to_s.should match /Error:/
    end

    it "handles die without a message" do
      sio = IO::Memory.new
      Optimist.options(%w(--potato)) do
        opt :potato
      end
      expect_raises(SystemExit) {
        Optimist.die :potato, stderr: sio
      }
      sio.to_s.should match /Error:/
    end

    it "fails with error code on an invalid option" do
      sio = IO::Memory.new
      expect_raises(SystemExit) do
        Optimist.options(%w(--potato), stderr: sio) { }
      end
      ex = expect_raises(SystemExit) {
        Optimist.options(%w(--potato), stderr: sio) { }
      }
      ex.error_code.should eq -1
    end
  end

  describe "callback" do
    it "yields an option to a block" do
      parser.opt "cb1", cls: StringOpt do |o|
        if o.value =~ /ab/
          raise RuntimeError.new("illegal")
        elsif o.is_a?(StringOpt)
          o.value = o.value.to_s.upcase
        end
      end

      # hit the illegal case
      expect_raises(RuntimeError, "illegal") do
        parser.parse(%w(--cb1 grabby))
      end

      # modify the option's value
      res = parser.parse(%w(--cb1 figleaf))
      res["cb1"].value.should eq "FIGLEAF"
    end

    it "yields nothing" do
      parser.opt "cb2", "with callback" do
        raise RuntimeError.new("brokeback")
      end
      expect_raises(RuntimeError, "brokeback") do
        parser.parse(%w(--cb2))
      end
    end
  end

  it "tests_ignore_invalid_options" do
    parser.opt :arg1, "desc", cls: StringOpt
    parser.opt :b, "desc", cls: StringOpt
    parser.opt :c, "desc", cls: BoolOpt
    parser.opt :d, "desc", cls: BoolOpt
    parser.ignore_invalid_options = true
    opts = parser.parse %w{unknown -S param --arg1 potato -fb daisy --foo -ecg --bar baz -z}
    opts["arg1"].value.should eq "potato"
    opts["b"].value.should eq "daisy"
    opts["c"].value.should eq true
    opts["d"].value.should eq false
    parser.leftovers.should eq %w{unknown -S param -f --foo -eg --bar baz -z}
  end

  it "tests_ignore_invalid_options_stop_on_unknown_long" do
    parser.opt :arg1, "desc", cls: StringOpt
    parser.ignore_invalid_options = true
    parser.stop_on_unknown
    opts = parser.parse %w{--unk --arg1 potato}

    opts["arg1"].value.should be_nil
    parser.leftovers.should eq %w{--unk --arg1 potato}
  end

  it "tests_ignore_invalid_options_stop_on_unknown_short" do
    parser.opt :arg1, "desc", cls: StringOpt
    parser.ignore_invalid_options = true
    parser.stop_on_unknown
    opts = parser.parse %w{-ua potato}
    opts["arg1"].value.should be_nil
    parser.leftovers.should eq %w{-ua potato}
  end

  it "tests_ignore_invalid_options_stop_on_unknown_partial_end_short" do
    parser.opt :arg1, "desc", cls: BoolOpt
    parser.ignore_invalid_options = true
    parser.stop_on_unknown
    opts = parser.parse %w{-au potato}
    opts["arg1"].value.should eq true
    parser.leftovers.should eq %w{-u potato}
  end

  it "tests_ignore_invalid_options_stop_on_unknown_partial_mid_short" do
    parser.opt :arg1, "desc", cls: BoolOpt
    parser.ignore_invalid_options = true
    parser.stop_on_unknown
    opts = parser.parse %w{-abu potato}
    opts["arg1"].value.should eq true
    parser.leftovers.should eq %w{-bu potato}
  end

  #
  #
  #  # Due to strangeness in how the cloaker works, there were
  #  # cases where Optimist.parse would work, but Optimist.options
  #  # did not, depending on arguments given to the function.
  #  # These serve to validate different args given to Optimist.options
  #  it "tests_options_takes_hashy_settings" do
  #    passargs_copy = []
  #    settings_copy = []
  #    ::Optimist.options(%w(--wig --pig), :fizz => :buzz, :bear => :cat) do |*passargs|
  #      opt :wig
  #      opt :pig
  #      passargs_copy = passargs.dup
  #      settings_copy = @settings
  #    end
  #    passargs_copy.should be_empty
  #    settings_copy[:fizz].should eq :buzz
  #    settings_copy[:bear].should eq :cat
  #  end
  #
  #  it "tests_options_takes_some_other_data" do
  #    passargs_copy = []
  #    settings_copy = []
  #    ::Optimist.options(%w(--nose --close), 1, 2, 3) do |*passargs|
  #      opt :nose
  #      opt :close
  #      passargs_copy = passargs.dup
  #      settings_copy = @settings
  #    end
  #    passargs_copy.should eq [1,2,3]
  #    settings_copy.should eq ::Optimist.Parser::DEFAULT_SETTINGS
  #  end

end
