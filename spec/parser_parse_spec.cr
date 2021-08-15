require "./spec_helper"

include Optimist
describe Optimist::Parser do

  parser = Optimist::Parser.new
  Spec.before_each do
    parser = Optimist::Parser.new
  end
  
  # TODO: parse
    # resolve_default_short_options!
    # parse_date_parameter
    # parse_integer_parameter(param, arg)
    # parse_float_parameter(param, arg)
    # parse_io_parameter(param, arg)
    # each_arg
      # collect_argument_parameters

  it "has help_needed" do
    parser.opt :arg
    expect_raises(HelpNeeded) { parser.parse %w(-h) }
    expect_raises(HelpNeeded) { parser.parse %w(--help) }
  end

  it "can override help" do
    parser.opt :arg1, "desc", long: "help"
    parser.parse(%w(-h)).has_key?("arg1").should be_true
    parser.parse(%w(--help)).has_key?("arg1").should be_true
  end

  it "can generate help with other args present" do
    parser.opt :arg1
    expect_raises(HelpNeeded) { parser.parse %w(--arg1 --help) }
  end

  it "can generate help with other args erroring" do
    parser.opt :arg1, type: String
    expect_raises(HelpNeeded) { parser.parse %w(--arg1 --help) }
  end

  it "generates error when -v called with version unset" do
    parser.opt :arg
    expect_raises(CommandlineError) { parser.parse %w(-v) }
  end

  it "produces a version when version is set" do
    parser.version = "optimist 5.2.3"
    expect_raises(VersionNeeded) { parser.parse %w(-v) }
    expect_raises(VersionNeeded) { parser.parse %w(--version) }
  end

  pending "handles manual version flag setting" do
    parser.opt :version
    parser.parse(%w(-v)).has_key?("version").should be true
    parser.parse(%w(-v)).["version"].given?.should_be true
  end

  it "produces VersionError only if version is set" do
    parser.opt :arg, ""
    expect_raises(CommandlineError) { parser.parse %w(-v) }
  end

  it "can generate version with other args present" do
    parser.opt :arg1, ""
    parser.version = "1.1"
    expect_raises(VersionNeeded) { parser.parse %w(--arg1 --version) }
  end

  it "can generate version with other args erroring" do
    parser.opt :arg1, "", type: String
    parser.version = "1.1"
    expect_raises(VersionNeeded) { parser.parse %w(--arg1 --version) }
  end



end
