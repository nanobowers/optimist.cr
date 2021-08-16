module Optimist
  # # Thrown by Parser in the event of a commandline error. Not needed if
  # # you're using the Optimist::options entry.
  class CommandlineError < Exception
    getter :error_code

    def initialize(msg, error_code : Int32? = nil)
      super(msg)
      @error_code = error_code
    end
  end

  # # Thrown by Parser if the user passes in '-h' or '--help'. Handled
  # # automatically by Optimist#options.
  class HelpNeeded < Exception
    getter :parser

    def initialize(parser : Parser)
      super("")
      @parser = parser
    end
  end

  # # Thrown by Parser if the user passes in '-v' or '--version'. Handled
  # # automatically by Optimist#options.
  class VersionNeeded < Exception
  end

  # # Replacement for exit() of sorts.
  class SystemExit < Exception
    getter :error_code

    def initialize(error_code : Int32 = 0)
      @error_code = error_code
    end
  end
end
