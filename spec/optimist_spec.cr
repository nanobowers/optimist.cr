require "./spec_helper"

include Optimist

module Optimist
  def self.reset_last_parser
    @@last_parser = nil
  end
end

describe Optimist do
  describe "module functions" do
    parser = Parser.new

    Spec.before_each do
      parser = Parser.new
      Optimist.disable_exit
      Optimist.reset_last_parser
    end

    Spec.after_each do
      Optimist.enable_exit
    end

    it "has options" do
      opts = Optimist.options ["-f"] do
        opt :f
      end
      opts["f"].value.should be_true
    end

    it "tests_options_die_default" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.options(["-f"], stderr: sio) do
          opt :x
        end
      end
      ex.error_code.should eq -1
      sio.to_s.should match /Error: unknown argument.*Try --help/mi
    end

    # This next test prints too much output
    # because there is no way to currently push a filehandle down into it.
    it "tests_options_die_educate_on_error" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.options(["-f"], stderr: sio) do
          opt :x
          educate_on_error
        end
      end
      sio.to_s.should match /Error: unknown argument.*Options/mi
    end

    it "tests_die_without_options_ever_run" do
      ex = expect_raises(ArgumentError, /die can only be called after/i) {
        Optimist.die "hello"
      }
    end

    it "tests_die" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) {
        Optimist.options([] of String) { }
        Optimist.die "issue with parsing", stderr: sio
      }
      ex.error_code.should eq -1
      sio.to_s.should match /Error: issue with parsing/
    end

    it "tests_die_custom_error_code" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.options([] of String) { }
        Optimist.die "issue with parsing", nil, 5, stderr: sio
      end
      ex.error_code.should eq 5
      sio.to_s.should match /Error: issue with parsing/
    end

    it "tests_die_custom_error_code_two_args" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.options([] of String) { }
        Optimist.die "issue with parsing", 5, stderr: sio
      end
      ex.error_code.should eq 5
      sio.to_s.should match /Error: issue with parsing/
    end

    it "tests_educate_without_options_ever_run" do
      # Signal::QUIT.trap do # expect_raises(System::Exit) {
      sio = IO::Memory.new
      ex = expect_raises(ArgumentError) do
        Optimist.educate(sio)
      end

      # end
    end

    it "tests_educate" do
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.options([] of String) { }
        Optimist.educate(sio)
      end
      ex.error_code.should eq 0
      sio.to_s.should match /Show this message/
    end
  end

  describe "with_standard_exception" do
    it "has options" do
      px = Parser.new
      px.opt :f
      sio = IO::Memory.new
      opts = Optimist.with_standard_exception_handling(px, stdout: sio) do
        px.parse ["-f"]
      end
      opts["f"].value.should be_true
    end

    it "has a version exception" do
      px = Parser.new
      px.version "5.5"
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stdout: sio) do
          raise VersionNeeded.new
        end
      end
      ex.error_code.should eq 0
      sio.to_s.should eq "5.5\n"
    end

    it "has a version flag" do
      px = Parser.new
      px.version "5.5"
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stdout: sio) do
          px.parse %w(-v)
        end
      end
      ex.error_code.should eq 0
      sio.to_s.should eq "5.5\n"
    end

    it "has die_exception" do
      px = Parser.new
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stderr: sio) do
          raise CommandlineError.new("cl error")
        end
      end
      ex.error_code.should eq -1
      sio.to_s.should match /Error: cl error/
    end

    it "can die_ex with a nondefault error_code" do
      px = Parser.new
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stderr: sio) do
          raise CommandlineError.new("cl five", 5)
        end
      end
      ex.error_code.should eq 5
      sio.to_s.should match /Error: cl five/
    end

    it "can die" do
      px = Parser.new
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stderr: sio) do
          px.die "cl error", stderr: sio
        end
      end
      ex.error_code.should eq -1
      sio.to_s.should match /Error: cl error/
    end

    it "can die with a custom error" do
      px = Parser.new
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stderr: sio) do
          px.die "cl error", nil, 3, stderr: sio
        end
      end
      ex.error_code.should eq 3
      sio.to_s.should match /Error: cl error/
    end

    it "has a help_needed" do
      px = Parser.new
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stdout: sio) do
          raise HelpNeeded.new(parser: px)
        end
      end
      ex.error_code.should eq 0
      sio.to_s.should match /Options/
    end

    it "has a help_needed_flag" do
      px = Parser.new
      sio = IO::Memory.new
      ex = expect_raises(SystemExit) do
        Optimist.with_standard_exception_handling(px, stdout: sio) do
          px.parse(%w(-h))
        end
      end
      ex.error_code.should eq 0
      sio.to_s.should match /Options/
    end
  end
end
