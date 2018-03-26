
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

enum LinCAS::ErrCode
    STRING_MEETS_EOF
    ILLEGAL_EXPRESSION
    INVALID_FLOAT
    INVALID_ID
    UNEXPECTED_TOKEN
    UNEXPECTED_EOF
    MISSING_IDENT
    MISSING_EOL
    MISSING_DOT 
    MISSING_L_BRACE
    MISSING_R_BRACE
    MISSING_L_PAR
    MISSING_R_PAR
    MISSING_L_BRACKET
    MISSING_R_BRACKET
    MISSING_EXPR
    MISSING_PIPE
    MISSING_COLON_EQ
    MISSING_NAME
    MISSING_UNTIL
    MISSING_COLON
    MISSING_DIR
    MISSING_FILENAME
    MISSING_LIBNAME
    CLASS_IN_VOID
    MODULE_IN_VOID
    UNALLOWED_PROTECTED
    INVALID_VISIB_ARG
    INVALID_ASSIGN
    INF_CONST_OUT_SYM
    IRREGULAR_MATRIX
    EMPTY_FUNCTION 
    ALREADY_SYM
    EXPECTING_CASE  
    INVALID_FILENAME
    UNLOCATED_LIB
    UNEXPECTED_RETURN
    UNEXPECTED_YIELD
    UNEXPECTED_NEXT
    RETURN_IN_BLOCK
end

module LinCAS
    private ErrDict = {
        ErrCode::STRING_MEETS_EOF    => "String meets end-of-line",
        ErrCode::ILLEGAL_EXPRESSION  => "Illegal expression",
        ErrCode::INVALID_ID          => "Invalid identifier format",
        ErrCode::UNEXPECTED_TOKEN    => "Unexpected token",
        ErrCode::UNEXPECTED_EOF      => "Unexpected end-of-file",
        ErrCode::MISSING_IDENT       => "Wrong or missing identifier",
        ErrCode::MISSING_EOL         => "Missing end-of-line or ';'",
        ErrCode::MISSING_DOT         => "Missing '.'",
        ErrCode::MISSING_L_BRACE     => "Missing '{'",
        ErrCode::MISSING_R_BRACE     => "Missing '}'",
        ErrCode::MISSING_L_PAR       => "Missing '('",
        ErrCode::MISSING_R_PAR       => "Missing ')'",
        ErrCode::MISSING_L_BRACKET   => "Missing '['",
        ErrCode::MISSING_R_BRACKET   => "Missing ']'",
        ErrCode::MISSING_EXPR        => "Missing expression",
        ErrCode::MISSING_PIPE        => "Missing '|'",
        ErrCode::MISSING_COLON_EQ    => "Missing ':='",
        ErrCode::MISSING_NAME        => "Missing name or namespace",
        ErrCode::MISSING_UNTIL       => "Missing keyword 'until'",
        ErrCode::MISSING_COLON       => "Missing ':'",
        ErrCode::MISSING_DIR         => "Missing keyword 'to' or 'downto'",
        ErrCode::MISSING_FILENAME    => "Missing fileneme string token",
        ErrCode::MISSING_LIBNAME     => "Missing library name string token",
        ErrCode::CLASS_IN_VOID       => "Class declaration inside a void",
        ErrCode::MODULE_IN_VOID      => "Module declaration inside a void",
        ErrCode::UNALLOWED_PROTECTED => "'Protected' keyword is not allowed outside classes/modules",
        ErrCode::INVALID_VISIB_ARG   => "Invalid argument for visibility keyword",
        ErrCode::INVALID_ASSIGN      => "Invalid assignment",
        ErrCode::INF_CONST_OUT_SYM   => "Infinity constant used out of a symbolic function",
        ErrCode::IRREGULAR_MATRIX    => "Irregular matrix row",
        ErrCode::ALREADY_SYM         => "Already declaring a symbolic function",
        ErrCode::EMPTY_FUNCTION      => "Declaring an empty symbolic function",
        ErrCode::EXPECTING_CASE      => "Unexpected token, expecting keyword 'case'",
        ErrCode::INVALID_FILENAME    => "Invalid filename",
        ErrCode::UNLOCATED_LIB       => "Library not found",
        ErrCode::UNEXPECTED_RETURN   => "'return' statement out of void or block",
        ErrCode::UNEXPECTED_YIELD    => "'yield' statement out of void",
        ErrCode::UNEXPECTED_NEXT     => "'next' statement out of block",
        ErrCode::RETURN_IN_BLOCK     => "Cant't return in block"
    }
    protected def convertErrCode(errCode)
        return ErrDict[errCode]
    end
end