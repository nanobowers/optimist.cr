module Optimist

  alias DefaultType = ( String | Nil | Float64 | Bool | Int32 | Array(String) | IO::FileDescriptor)
  alias PermittedType = ( Array(String|Int32) | Regex | Range(Int32,Int32) | Nil )
  alias AlternatesType = ( Array(String) | String | Nil )

end
