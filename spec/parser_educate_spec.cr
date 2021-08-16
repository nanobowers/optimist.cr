require "./spec_helper"

include Optimist

def assert_educates(parser, search_regex)
  sio = IO::Memory.new
  parser.educate sio
  sio.to_s.should match(search_regex)
end

def helplines(parser)
  sio = IO::Memory.new
  parser.educate sio
  sio.to_s.chomp.split "\n"
end

describe Optimist do
  describe "ParserEducate" do
    parser = Parser.new
    Spec.before_each do
      parser = Parser.new
    end

    it "tests_no_arguments_to_stdout" do
      # assert_stdout(/Options:/) do
      parser.educate
      # end
    end

    it "tests_argument_to_stringio" do
      assert_educates(parser, /Options:/)
    end

    it "tests_no_headers" do
      assert_educates(parser, /^Options:/)
    end

    it "tests_usage" do
      parser.usage "usage string"
      assert_educates(parser, /^Usage: \S* usage string\n\nOptions:/)
    end

    #    it "tests_usage_synopsis_version" do
    #    end

    # def test_banner
    # def test_text

    # width, legacy_width
    # wrap
    # wrap_lines

    describe "help" do
      it "has a default_banner" do
        parser = Parser.new
        parser.parse([] of String)
        help = helplines(parser)
        help[0].should match(/options/i)
        help.size.should eq 2 # options, then -h

        parser = Parser.new
        parser.version "my version"
        parser.parse([] of String)
        help = helplines(parser)
        help[0].should match(/my version/i)
        help.size.should eq 4 # version, options, -h, -v

        parser = Parser.new
        parser.banner "my own banner"
        parser.parse([] of String)
        help = helplines(parser)
        help[0].should match(/my own banner/i)
        help.size.should eq 2 # banner, then -h
      end

      it "has an optional usage" do
        parser = Parser.new
        parser.usage "OPTIONS FILES"
        parser.parse([] of String)
        help = helplines(parser)
        help[0].should match(/OPTIONS FILES/i)
        help.size.should eq 4 # line break, options, then -h
      end

      it "has an optional synopsis" do
        parser = Parser.new
        parser.synopsis "About this program"
        parser.parse([] of String)
        help = helplines(parser)
        help[0].should match(/About this program/i)
        help.size.should eq 4 # line break, options, then -h
      end

      it "has a specific order for usage and synopsis" do
        parser = Parser.new
        parser.usage "OPTIONS FILES"
        parser.synopsis "About this program"
        parser.parse([] of String)
        help = helplines(parser)
        help[0].should match(/OPTIONS FILES/i)
        help[1].should match(/About this program/i)
        help.size.should eq 5 # line break, options, then -h
      end

      it "preserves order/positions" do
        parser.opt :zzz, "zzz"
        parser.opt :aaa, "aaa"
        help = helplines(parser)
        help[1].should match(/zzz/)
        help[2].should match(/aaa/)
      end

      it "includes option types" do
        parser.opt :arg1, "arg", cls: Int32Opt
        parser.opt :arg2, "arg", cls: Int32ArrayOpt
        parser.opt :arg3, "arg", cls: StringOpt
        parser.opt :arg4, "arg", cls: StringArrayOpt
        parser.opt :arg5, "arg", cls: Float64Opt
        parser.opt :arg6, "arg", cls: Float64ArrayOpt
        parser.opt :arg7, "arg", cls: FileOpt
        # parser.opt :arg8, "arg", cls: :ios
        # parser.opt :arg9, "arg", cls: :date
        # parser.opt :arg10, "arg", cls: :dates
        help = helplines(parser)
        help[1].should match(/<i>/)
        help[2].should match(/<i\+>/)
        help[3].should match(/<s>/)
        help[4].should match(/<s\+>/)
        help[5].should match(/<f>/)
        help[6].should match(/<f\+>/)
        help[7].should match(/<filename\/uri>/)
        # help[8].should match(/<filename\/uri\+>/)
        # help[9].should match(/<date>/)
        # help[10].should match(/<date\+>/)
      end

      it "has a default text" do
        parser.opt :arg1, "description with period.", default: "hello"
        parser.opt :arg2, "description without period", default: "world"
        help = helplines(parser)
        help[1].should match(/Default/)
        help[2].should match(/Default/)
      end
    end
  end
end
