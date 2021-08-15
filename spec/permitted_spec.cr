require "./spec_helper"
include Optimist


describe Optimist do
  
  parser = Optimist::Parser.new
  Spec.before_each do
    parser = Optimist::Parser.new
  end

  describe "Permitted" do
    
#
#  it "tests_permitted_invalid_value" do
#    err_regexp = /permitted values for option "(bad|mad|sad)" must be either nil, Range, Regexp or an Array/
#    expect_raises(ArgumentError, err_regexp) {
#      parser.opt "bad", "desc", permitted: 1
#    }
#    expect_raises(ArgumentError, err_regexp) {
#      parser.opt "mad", "desc", permitted: "A"
#    }
#    expect_raises(ArgumentError, err_regexp) {
#      parser.opt "sad", "desc", permitted: :abcd
#    }
#  end

  it "tests_permitted_with_string_array" do
    parser.opt "fiz", "desc", cls: StringOpt, permitted: ["foo", "bar"]
    parser.parse(%w(--fiz foo))
    expect_raises(CommandlineError, /option '--fiz' only accepts one of: foo, bar/) {
      parser.parse(%w(--fiz buz))
    }
  end
  
  it "tests_permitted_with_symbol_array" do
    parser.opt "fiz", "desc", cls: StringOpt, permitted: %w[dog cat]
    parser.parse(%w(--fiz dog)) 
    parser.parse(%w(--fiz cat)) 
    expect_raises(CommandlineError, /option '--fiz' only accepts one of: dog, cat/) {
      parser.parse(%w(--fiz rat))
    }
  end

  it "tests_permitted_with_numeric_array" do
    parser.opt "mynum", "desc", cls: Int32Opt, permitted: [1,2,4]
    parser.parse(%w(--mynum 1)) 
    parser.parse(%w(--mynum 4)) 
    expect_raises(CommandlineError, /option '--mynum' only accepts one of: 1, 2, 4/) {
      parser.parse(%w(--mynum 3))
    }
  end

  it "tests_permitted_with_numeric_range" do
    parser.opt "fiz", "desc", cls: Int32Opt, permitted: 1..3
    opts = parser.parse(%w(--fiz 1))
    opts["fiz"].value.should eq 1
    opts = parser.parse(%w(--fiz 3))
    opts["fiz"].value.should eq 3
    expect_raises(CommandlineError, /option '--fiz' only accepts value in range of: 1\.\.3/) {
      parser.parse(%w(--fiz 4))
    }
  end

  it "tests_permitted_with_regexp" do
    parser.opt "zipcode", "desc", cls: StringOpt, permitted: /^[0-9]{5}$/
    parser.parse(%w(--zipcode 39762))
    err_regexp = %r|option '--zipcode' only accepts value matching: ...0.9..5|
    expect_raises(CommandlineError, err_regexp) {
      parser.parse(%w(--zipcode A9A9AA))
    }
  end
  
  it "tests_permitted_with_reason" do
    # test all keys passed into the formatter for the permitted_response
    parser.opt "zipcode", "desc", cls: StringOpt, permitted: /^[0-9]{5}$/,
           permitted_response: "opt %{arg} should be a zipcode but you have %{value}"
    parser.opt :wig, "wig", cls: Int32Opt, permitted: 1..4,
           permitted_response: "opt %{arg} exceeded four wigs (%{valid_string}), %{permitted}, but you gave '%{given}'"
    err_regexp = %r|opt --zipcode should be a zipcode but you have A9A9AA|
    expect_raises(CommandlineError, err_regexp) {
      parser.parse(%w(--zipcode A9A9AA))
    }
    err_regexp = %r|opt --wig exceeded four wigs \(value in range of: 1\.\.4\), 1\.\.4, but you gave '5'|
    expect_raises(CommandlineError, err_regexp) {
      parser.parse(%w(--wig 5))
    }
  end

  
end
end
