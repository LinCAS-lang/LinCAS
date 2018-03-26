
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS
    private TokenDictConverter = 
            {
                # Math functions
                # "log"   => TkType::LOG,
                # "exp"   => TkType::EXP,
                # "tan"   => TkType::TAN,
                # "atan"  => TkType::ATAN,
                # "cos"   => TkType::COS,
                # "acos"  => TkType::ACOS,
                # "sin"   => TkType::SIN,
                # "asin"  => TkType::ASIN,
                # "sqrt"  => TkType::SQRT,

                # Math constants
                # "inf"  => TkType::INF,
                # "ninf" => TkType::NINF,
                # "e"    => TkType::E,
                # "pi"   => TkType::PI,

                # Keywords
                "if"         => TkType::IF,
                "elsif"      => TkType::ELSIF,
                "then"       => TkType::THEN,
                "else"       => TkType::ELSE,
                "void"       => TkType::VOID,
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
                "include"    => TkType::INCLUDE,
                "use"        => TkType::USE,
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
                "^"   => TkType::POWER,
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
                "^="  => TkType::POWER_EQ,
                "\""  => TkType::QUOTES,
                "'"   => TkType::S_QUOTE,
                "$"   => TkType::DOLLAR,
                "[]=" => TkType::ASSIGN_INDEX,
                "$."  => TkType::ANS
            }

    protected def toTkType(tkName : String)
        return TokenDictConverter[tkName.downcase]?
    end

    protected def isSpecialChar?(charTk)
        TokenDictConverter.has_key? charTk
    end
end