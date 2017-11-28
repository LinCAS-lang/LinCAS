
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
    MISSING_EXPR
    MISSING_COLON_EQ
    CLASS_IN_VOID
    MODULE_IN_VOID
    UNALLOWED_PROTECTED
    INVALID_VISIB_ARG
    INVALID_ASSIGN
    INF_CONST_OUT_SYM
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
        ErrCode::MISSING_EXPR        => "Missing expression",
        ErrCode::MISSING_COLON_EQ    => "Missing ':='",
        ErrCode::CLASS_IN_VOID       => "Class declaration inside a void",
        ErrCode::MODULE_IN_VOID      => "Module declaration inside a void",
        ErrCode::UNALLOWED_PROTECTED => "'Protected' keyword is not allowed outside classes/modules",
        ErrCode::INVALID_VISIB_ARG   => "Invalid argument for visibility keyword",
        ErrCode::INVALID_ASSIGN      => "Invalid assignment",
        ErrCode::INF_CONST_OUT_SYM   => "Infinity constant used out of a symbolic function"
    }
    protected def convertErrCode(errCode)
        return ErrDict[errCode]
    end
end