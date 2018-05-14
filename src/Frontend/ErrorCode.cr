
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
    MISSING_ARROW
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
    DYNAMIC_CONST
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
        ErrCode::MISSING_ARROW       => "Missing '=>'",
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
        ErrCode::UNEXPECTED_RETURN   => "'return' statement out of void",
        ErrCode::UNEXPECTED_YIELD    => "'yield' statement out of void",
        ErrCode::UNEXPECTED_NEXT     => "'next' statement out of block",
        ErrCode::RETURN_IN_BLOCK     => "Cant't return in block",
        ErrCode::DYNAMIC_CONST       => "Dynamic const assignment"
    }
    protected def convertErrCode(errCode)
        return ErrDict[errCode]
    end
end
