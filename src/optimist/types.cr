module Optimist

  alias Ident = String ## option-identifier
  
  alias DefaultType = ( String | Nil | Float64 | Bool | Int32 | Array(String) | Array(Int32) | Array(Float64) | IO::FileDescriptor)
  alias PermittedType = ( Array(String) | Array(Int32) | Regex | Range(Int32,Int32) | Nil )
  alias LongNameType = (Symbol | String | Nil)
  alias AlternatesType = ( Array(String|Symbol) | Symbol | String | Nil )

  alias ShortNameType = ( Array(String|Char|Symbol) | String | Char | Symbol | Bool | Nil)
end
