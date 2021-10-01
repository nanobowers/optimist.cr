module Optimist
  # :nodoc:
  alias Ident = String # # option-identifier

  # :nodoc:
  alias DefaultType = (String | Nil | Float64 | Bool | Int32 | Array(String) | Array(Int32) | Array(Float64) | IO::FileDescriptor)

  # :nodoc:
  alias PermittedType = (Array(String) | Array(Int32) | Regex | Range(Int32, Int32) | Nil)
  
  # :nodoc:
  alias LongNameType = String?

  # :nodoc:
  alias AlternatesType = (Array(String) | String | Nil)

  # :nodoc:
  alias SingleShortNameType = String | Char

  # :nodoc:
  alias MultiShortNameType = Array(String | Char)

  # :nodoc:
  alias ShortNameType = (MultiShortNameType | SingleShortNameType | Bool | Nil)
end
