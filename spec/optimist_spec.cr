require "./spec_helper"

include Optimist

describe Optimist do

  parser = Parser.new
  
  Spec.before_each do
    parser = Parser.new
    #Optimist.send(:instance_variable_set, "@last_parser", nil)
  end


  it "tests_options" do       
    opts = Optimist.options ["-f"] do
      opt :f
    end
    opts["f"].value.should be_true
  end

  pending "tests_options_die_default" do
    assert_stderr(/Error: unknown argument.*Try --help/m) do
      assert_system_exit(-1) do
        Optimist.options ["-f"] do
          opt :x
        end
      end
    end
  end

  pending "tests_options_die_educate_on_error" do
    assert_stderr(/Error: unknown argument.*Options/m) do
      assert_system_exit(-1) do
        Optimist.options ["-f"] do
          opt :x
          educate_on_error
        end
      end
    end
  end

  pending "tests_die_without_options_ever_run" do
    expect_raises(ArgumentError) { Optimist.die "hello" }
  end

  pending "tests_die" do
    assert_stderr(/Error: issue with parsing/) do
      assert_system_exit(-1) do
        Optimist.options [] of String
        Optimist.die "issue with parsing"
      end
    end
  end

  pending "tests_die_custom_error_code" do
    assert_stderr(/Error: issue with parsing/) do
      assert_system_exit(5) do
        Optimist.options [] of String
        Optimist.die "issue with parsing", nil, 5
      end
    end
  end

  pending "tests_die_custom_error_code_two_args" do
    assert_stderr(/Error: issue with parsing/) do
      assert_system_exit(5) do
        Optimist.options [] of String
        Optimist.die "issue with parsing", 5
      end
    end
  end

  it "tests_educate_without_options_ever_run" do
    Signal::QUIT.trap do # expect_raises(System::Exit) {
      Optimist.educate
    end

  end

  pending "tests_educate" do
    assert_stdout(/Show this message/) do
      assert_system_exit(0) do
        Optimist.options [] of String
        Optimist.educate
      end
    end
  end


  describe "with_standard_exception" do
    
    it "has options" do
      px = Parser.new
      px.opt :f

      opts = Optimist.with_standard_exception_handling px do
        px.parse ["-f"]
      end

      opts["f"].value.should be_true
    end

    pending "has version_exception" do
      p = parser do
        version "5.5"
      end

      assert_stdout(/5\.5/) do
        assert_system_exit(0) do
          Optimist.with_standard_exception_handling px do
            raise VersionNeeded
          end
        end
      end
    end

    pending "has version_flag" do
      px = parser do
        version "5.5"
      end

      assert_stdout(/5\.5/) do
        assert_system_exit(0) do
          Optimist.with_standard_exception_handling px do
            p.parse %w(-v)
          end
        end
      end
    end

    pending "has die_exception" do
      assert_stderr(/Error: cl error/) do
        assert_system_exit(-1) do
          px = parser
          Optimist.with_standard_exception_handling(px) do
            raise CommandlineError.new("cl error")
          end
        end
      end
    end

    pending "has die_exception_custom_error" do
      assert_stderr(/Error: cl error/) do
        assert_system_exit(5) do
          px = parser
          Optimist.with_standard_exception_handling(px) do
            raise CommandlineError.new("cl error", 5)
          end
        end
      end
    end

    pending "can die" do
      assert_stderr(/Error: cl error/) do
        assert_system_exit(-1) do
          px = parser
          Optimist.with_standard_exception_handling(px) do
            px.die "cl error"
          end
        end
      end
    end

    pending "has a die_custom_error" do
      assert_stderr(/Error: cl error/) do
        assert_system_exit(3) do
          px = parser
          Optimist.with_standard_exception_handling(px) do
            px.die "cl error", nil, 3
          end
        end
      end
    end

    pending "has a help_needed" do
      assert_stdout(/Options/) do
        assert_system_exit(0) do
          px = parser
          Optimist.with_standard_exception_handling(px) do
            raise HelpNeeded.new(parser: px)
          end
        end
      end
    end

    pending "has a help_needed_flag" do
      assert_stdout(/Options/) do
        assert_system_exit(0) do
          px = parser
          Optimist.with_standard_exception_handling(px) do
            px.parse(%w(-h))
          end
        end
      end
    end

  end
  
end
