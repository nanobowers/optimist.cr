require "./spec_helper"

include Optimist

private def hn(par : Parser)
  HelpNeeded.new(parser: par)
end

describe Optimist do
  describe HelpNeeded do
    it "is a class" do
      par = Parser.new
      hn(par).should be_a Exception
    end

    it "has a message" do
      par = Parser.new
      hn(par).message.should eq ""
    end
  end
end
