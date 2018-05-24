
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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
    private TokenDictConverter = 
            {

                # Keywords
                "if"         => TkType::IF,
                "elsif"      => TkType::ELSIF,
                "then"       => TkType::THEN,
                "else"       => TkType::ELSE,
                "let"        => TkType::FUNC,
                "ahead"      => TkType::AHEAD,
                "select"     => TkType::SELECT,
                "case"       => TkType::CASE,
                "while"      => TkType::WHILE,
                "until"      => TkType::UNTIL,
                "do"         => TkType::DO,
                "for"        => TkType::FOR,
                "to"         => TkType::TO,
                "downto"     => TkType::DOWNTO,
                "class"      => TkType::CLASS,
                "module"     => TkType::MODULE,
                "public"     => TkType::PUBLIC,
                "protected"  => TkType::PROTECTED,
                "private"    => TkType::PRIVATE,
                "inherits"   => TkType::INHERITS,
                "const"      => TkType::CONST,
                "new"        => TkType::NEW,
                "require"    => TkType::REQUIRE,
                "require_relative" => TkType::REQUIRE_RELATIVE,
                "include"    => TkType::INCLUDE,
                "use"        => TkType::USE,
                "import"     => TkType::IMPORT,
                "self"       => TkType::SELF,
                "yield"      => TkType::YIELD,
                "raise"      => TkType::RAISE,
                "__file__"   => TkType::FILEMC,
                "__dir__"    => TkType::DIRMC,
                "try"        => TkType::TRY,
                "catch"      => TkType::CATCH,

                # Internal values
                "true"  => TkType::TRUE,
                "false" => TkType::FALSE,
                "null"  => TkType::NULL,

                # Internal methods
                "print"  => TkType::PRINT,
                "printl" => TkType::PRINTL,
                "return" => TkType::RETURN,
                "reads"  => TkType::READS,
                "next"   => TkType::NEXT,

                # Special chars
                "."   => TkType::DOT,
                ".."  => TkType::DOT_DOT,
                "..." => TkType::DOT_DOT_DOT,
                "+"   => TkType::PLUS,
                "-"   => TkType::MINUS,
                "*"   => TkType::STAR,
                "/"   => TkType::SLASH,
                "\\"  => TkType::BSLASH,
                "**"  => TkType::POWER,
                "^"   => TkType::B_XOR,
                ">"   => TkType::GREATER,
                "<"   => TkType::SMALLER,
                ">="  => TkType::GREATER_EQ,
                "<="  => TkType::SMALLER_EQ,
                "<>"  => TkType::NOT_EQ,
                "=="  => TkType::EQ_EQ,
                "="   => TkType::EQ,
                "%"   => TkType::MOD,
                "!"   => TkType::NOT,
                "!="  => TkType::NOT_EQ,
                "&"   => TkType::ADD,
                "&&"  => TkType::AND,
                "|"   => TkType::PIPE,
                "||"  => TkType::OR,
                ":"   => TkType::COLON,
                "::"  => TkType::COLON2,
                ";"   => TkType::SEMICOLON,
                ","   => TkType::COMMA,
                ":="  => TkType::COLON_EQ,
                "<<"  => TkType::APPEND,
                "("   => TkType::L_PAR,
                ")"   => TkType::R_PAR,
                "{"   => TkType::L_BRACE,
                "}"   => TkType::R_BRACE,
                "["   => TkType::L_BRACKET,
                "]"   => TkType::R_BRACKET,
                "+="  => TkType::PLUS_EQ,
                "-="  => TkType::MINUS_EQ,
                "*="  => TkType::STAR_EQ,
                "/="  => TkType::SLASH_EQ,
                "\\=" => TkType::BSLASH_EQ,
                "%="  => TkType::MOD_EQ,
                "**=" => TkType::POWER_EQ,
                "^="  => TkType::B_XOR_EQ,
                "\""  => TkType::QUOTES,
                "'"   => TkType::S_QUOTE,
                "$"   => TkType::DOLLAR,
                "[]=" => TkType::ASSIGN_INDEX,
                "$!"  => TkType::ANS,
                "-@"  => TkType::UMINUS,
                "=>"  => TkType::ARROW
            }

    protected def toTkType(tkName : String)
        return TokenDictConverter[tkName.downcase]?
    end

    protected def isSpecialChar?(charTk)
        TokenDictConverter.has_key? charTk
    end
end
