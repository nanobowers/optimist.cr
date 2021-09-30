require "./spec_helper"

include Optimist

describe Optimist do
  describe StringFlagOpt do
    parser = Parser.new
    Spec.before_each do
      parser = Parser.new
    end

    # in this case, the stringflag should return false
    it "works when unset" do
      parser.opt :sfo, "desc", cls: StringFlagOpt
      parser.opt :abc, "desc", cls: BoolOpt
      opts = parser.parse %w()
      opts["sfo"].value.should be_false
      opts["abc"].value.should be_false
      opts = parser.parse %w(--abc)
      opts["sfo"].value.should be_false
      opts["abc"].value.should be_true
    end

    # in this case, the stringflag should return true
    it "acts as a flag" do
      parser.opt :sfo, "desc", cls: StringFlagOpt
      parser.opt :abc, "desc", cls: BoolOpt

      opts = parser.parse %w(--sfo)
      opts["sfo"].given?.should be_true
      opts["sfo"].value.should be_true
      opts["abc"].value.should be_false

      opts = parser.parse %w(--sfo --abc)
      opts["sfo"].given?.should be_true
      opts["sfo"].value.should be_true
      opts["abc"].value.should be_true
    end

    # in this case, the stringflag should return a string
    it "acts as a String" do
      parser.opt :sfo, "desc", cls: StringFlagOpt
      parser.opt :abc, "desc", cls: BoolOpt
      opts = parser.parse %w(--sfo abcd)
      opts["sfo"].given?.should be_true
      opts["sfo"].value.should eq "abcd"
      opts["abc"].value.should be_false
      opts = parser.parse %w(--sfo abcd --abc)
      opts["sfo"].given?.should be_true
      opts["sfo"].value.should eq "abcd"
      opts["abc"].value.should be_true
    end

    it "acts as a String with a String default" do
      parser.opt :log, "desc", cls: StringFlagOpt, default: "output.log"
      opts = parser.parse([] of String)
      opts["log"].given?.should be_false
      opts["log"].value.should eq "output.log"

      opts = parser.parse %w(--no-log)
      opts["log"].given?.should be_true
      opts["log"].value.should be_false

      opts = parser.parse %w(--log)
      opts["log"].given?.should be_true
      opts["log"].value.should eq "output.log"

      opts = parser.parse %w(--log other.log)
      opts["log"].given?.should be_true
      opts["log"].value.should eq "other.log"
    end

    it "works without a default" do
      parser.opt :log, "desc", cls: StringFlagOpt

      opts = parser.parse([] of String)
      opts["log"].given?.should be_false
      opts["log"].value.should be_false

      opts = parser.parse %w(--no-log)
      opts["log"].given?.should be_true
      opts["log"].value.should be_false

      opts = parser.parse %w(--log)
      opts["log"].given?.should be_true
      opts["log"].value.should be_true

      opts = parser.parse %w(--log other.log)
      opts["log"].given?.should be_true
      opts["log"].value.should eq "other.log"
    end
  end
end
