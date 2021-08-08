require "./spec_helper"

describe "Optimist" do

  it "makes a flag option" do
    opts = Optimist.options %w(-f -g a b b c --good cc b a -- foo ) do
      opt :f
      opt :good
    end
    #p opts[:f]
  end

  it "makes a flag option" do
    opts = Optimist.options %w(-f 1.0 3.0 -f 2.0) do
      opt :f
    end
    #p opts[:f]
  end
  
end
