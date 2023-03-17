# Copyright (c) 2020 Massimiliano Dal Mas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module LinCAS

  # enum Tk 
  #   EOF 
  #   EOL
  #   SPACE
  #   # KwCASE
  #   # KwCATCH
  #   # KwCLASS
  #   # KwMODULE
  #   # KwLET
  #   # KwRETURN
  #   # KwNEXT
  #   SEMICOLON
  #   COMMA
  #   LPAR
  #   RPAR
  #   LBRACKET
  #   RBRAKET
  #   LBRACE 
  #   RBRACE 
  #   PIPE
  #   QUOTES
  #   QUOTE
  #   DOT
  #   DOT2
  #   DOT3
  #   PLUS
  #   PLUS_EQ
  #   MINUS
  #   UMINUS
  #   MINUS_EQ
  #   STAR
  #   STAR_EQ
  #   STAR2
  #   STAR2_EQ
  #   SLASH
  #   SLASH_EQ
  #   REGEXP_D
  #   BSLASH
  #   BSLASH_EQ
  #   B_XOR
  #   B_XOR_EQ
  #   OR 
  #   OR_EQ
  #   B_OR_EQ
  #   GREATER
  #   R_SHIFT
  #   GREATER_EQ
  #   LESS 
  #   L_SHIFT
  #   LESS_EQ
  #   COLON
  #   COLON2 
  #   COLON_EQ
  #   MOD 
  #   MOD_EQ
  #   NOT 
  #   NOT_EQ
  #   EQ 
  #   EQ2
  #   EQ3
  #   AND 
  #   AND_EQ 
  #   B_AND 
  #   B_AND_EQ
  #   
  #   R_ARROW
  #   QMARK
  #   SYMBOL
  #   QUOTED_SYM_BEG
  #   ANS
  #   DOLLAR
  #   INT 
  #   FLOAT
  #   COMPLEX
  #   CLASS_VAR 
  #   INSTANCE_VAR
  #   CAPITAL_VAR
  #   IDENT
  #   INTERP_BEG
  # end

  class Token

    record DelimiterType,
      type          : Symbol,
      delimiter     : Char,
      interpolation : Bool,
      escape        : Bool do 
    end

    property location : Location
    property type, value, raw, is_kw, delimiter_t, passed_backslash_newline
    
    @value : String | Symbol 
    
    {%for name in %w(initialize reset)%}
      def {{name.id}}
        @location    = Location.new(0,0,0)
        @type        = :EOF
        @value       = ""
        @raw         = ""
        @is_kw       = false
        @delimiter_t = DelimiterType.new(:"\"", ',', false, false)
        @passed_backslash_newline = false
      end
    {% end %}

    def copy_from(token)
      @location    = token.location
      @type        = token.type 
      @value       = token.value
      @raw         = token.raw
      @is_kw       = token.is_kw
      @delimiter_t = token.delimiter_t
    end

    def to_s(io)
      io << @type << ' ' << @value.inspect << ' ' 
      io << @raw.inspect << ' ' << @location.line 
      io << ':' << @location.column
      io << (is_kw ? " kw" : " no-kw")
    end

    def keyword?(kw)
      return @is_kw && @value == kw
    end 
  end
end