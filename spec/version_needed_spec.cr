require "./spec_helper"

include Optimist

private def vn(*args)
  VersionNeeded.new(*args)
end

describe Optimist do
  describe VersionNeeded do


    it "is an exception" do
      vn("message").should be_a Exception
    end

    it "makes a message" do
      vn("message").message.should eq "message"
    end

  end
end
