require "./spec_helper"

include Optimist

private def cle(*args)
  CommandlineError.new(*args)
end

describe Optimist do

  describe CommandlineError do
  

    it "is a class" do
      cle("message").should be_a Exception
    end

    it "has a message" do
      cle("message").message.should eq "message"
    end

    it "has a default error code" do
      cle("message").error_code.should be_nil
    end

    
    it "takes a custom error code" do
      cle("message", -3).error_code.should eq(-3)
    end

  end
end
