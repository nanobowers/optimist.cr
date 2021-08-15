require "./spec_helper"

include Optimist

def get_help_string(parser)
  err = expect_raises(Optimist::HelpNeeded) do
    parser.parse(%w(--help))
  end
  sio = IO::Memory.new
  parser.educate sio
  sio.to_s
end


describe Optimist do

  parser = Optimist::Parser.new
  Spec.before_each do
    parser = Optimist::Parser.new
  end

  describe "AlternateNames" do

    it "tests_altshort" do
       parser.opt :catarg, "desc", short: ["c", "-C"]
       opts = parser.parse %w(-c)
       opts["catarg"].value.should be_true
       opts = parser.parse %w(-C)
       opts["catarg"].value.should be_true
       expect_raises(CommandlineError) { parser.parse %w(-c -C) }
       expect_raises(CommandlineError) { parser.parse %w(-cC) }
    end

    it "tests_altshort_with_multi" do
      parser.opt :flag, "desc", short: ["-c", 'C', :x], multi: true
      parser.opt :num, "desc", short: ["-n", 'N'], cls: Int32ArrayOpt
      parser.parse %w(-c)
      parser.parse %w(-C -c -x)
      parser.parse %w(-c -C)
      parser.parse %w(-c -C -c -C)
      opts = parser.parse %w(-ccCx)
      opts["flag"].value.should be_true
      parser.parse %w(-c)
      parser.parse %w(-N 1 -n 3)
      parser.parse %w(-n 2 -N 4)
      opts = parser.parse %w(-n 4 -N 3 -n 2 -N 1)
      opts["num"].value.should eq [4, 3, 2, 1]
    end

    it "tests_altlong" do
      parser.opt :goodarg0, "desc", alt: "zero"
      parser.opt :goodarg1, "desc", long: "newone", alt: "one"
      parser.opt :goodarg2, "desc", alt: "--two"
      parser.opt :goodarg3, "desc", alt: ["three", "--four", :five]

      [%w[--goodarg0], %w[--zero]].each do |a|
        opts = parser.parse(a)
        opts["goodarg0"].value.should be_true
      end
      
      [%w[--newone], %w[-n], %w[--one]].each  do |a|
        opts = parser.parse(a)
        opts["goodarg1"].value.should be_true
      end

      [%w[--two]].each  do |a|
        opts = parser.parse(a)
        opts["goodarg2"].value.should be_true
      end

      [%w[--three], %w[--four], %w[--five]].each  do |a|
        opts = parser.parse(a)
        opts["goodarg3"].value.should be_true
      end

      [%w[--goodarg1], %w[--missing], %w[-a]].each do |a|
        expect_raises(CommandlineError) { parser.parse(a) }
      end

      ["", "--", "-bad", "---threedash"].each do |altitem|
        expect_raises(ArgumentError) { parser.opt :badarg, "desc", alt: altitem }
      end
    end
    
    it "tests_altshort_help" do
      parser.opt :cat, "cat", short: ['c','C','a','T']
      outstring = get_help_string(parser)
      # expect mutliple short-opts to be in the help
      outstring.should match(/-c, -C, -a, -T, --cat/)
    end

    
    it "tests_altlong_help" do
      parser.opt :cat, "a cat", alt: :feline
      parser.opt :dog, "a dog", alt: ["Pooch", :canine]
      parser.opt :fruit, "a fruit", long: :fig, alt: ["peach", :pear, "--apple"], short: false

      outstring = get_help_string(parser)

      outstring.should match(/-c, --cat, --feline/)
      outstring.should match(/-d, --dog, --Pooch, --canine/)

      # expect long-opt to shadow the actual name
      outstring.should match(/--fig, --peach, --pear, --apple/)
      
    end

    it "tests_alt_duplicates" do
      # alt duplicates named option
      expect_raises(ArgumentError) {
        parser.opt :cat, "desc", alt: :cat
      }
      # alt duplicates :long 
      expect_raises(ArgumentError) {
        parser.opt :cat, "desc", long: :feline, alt: [:feline]
      }
      # alt duplicates itself
      expect_raises(ArgumentError) {
        parser.opt :abc, "desc", alt: [:aaa, :aaa]
      }
    end
    
    it "tests_altlong_collisions" do
      parser.opt :fat, "desc"
      parser.opt :raton, "desc", long: :rat
      parser.opt :bat, "desc", alt: [:baton, :twirl]

      # :alt collision with named option
      expect_raises(ArgumentError) {
        parser.opt :cat, "desc", alt: :fat
      }

      # :alt collision with :long option
      expect_raises(ArgumentError) {
        parser.opt :cat, "desc", alt: :rat
      }

      # :named option collision with existing :alt option
      expect_raises(ArgumentError) {
        parser.opt :baton, "desc"
      }

      # :long option collision with existing :alt option
      expect_raises(ArgumentError) {
        parser.opt :whirl, "desc", long: "twirl"
      }
      
    end
  end
end
