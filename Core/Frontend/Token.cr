
module LinCAS

    enum TkType
        # Generic
        STRING ERROR INT FLOAT EOL EOF GLOBAL_ID LOCAL_ID

        # Math functions
        LOG EXP TAN ATAN COS ACOS SIN ASIN SQRT

        # Math constants
        INF NINF E PI

        # Keywords
        IF ELSIF THEN ELSE VOID AHEAD SELECT CASE WHILE UNTIL DO
        FOR TO DOWNTO CLASS MODULE PUBLIC PROTECTED PRIVATE INHERITS
        CONST NEW REQUIRE INCLUDE USE SELF YIELD

        # Internal values
        TRUE FALSE NULL

        # Internal methods 
        PRINT PRINTL RETURN READS

        # Special chars
        DOT DOT_DOT DOT_DOT_DOT MINUS PLUS STAR SLASH BSLASH POWER
        GREATER SMALLER GREATER_EQ SMALLER_EQ NOT_EQ EQ_EQ EQ MOD
        NOT ADD AND PIPE OR COLON SEMICOLON COMMA COLON_EQ APPEND
        L_PAR R_PAR L_BRACE R_BRACE L_BRACKET R_BRACKET PLUS_EQ
        MINUS_EQ STAR_EQ SLASH_EQ BSLASH_EQ MOD_EQ POWER_EQ QUOTES
        S_QUOTE DOLLAR
    end
    
    abstract struct Token
        
        @ttype = uninitialized TkType
        @text  = ""
        @value = uninitialized (Int32 | Int64 | Float32 | Float64 | ErrCode)

        property ttype
        property text
        property line
        property pos
        property value

        def initialize(@source : Source)
            @pos  = @source.getPos.as(Int32 | Int64)
            @line = @source.getLine.as(Int32 | Int64)
            extract 
        end
        
        def value?
            @value if @value
        end

        protected def nextChar
            @source.nextChar
        end

        protected def currentChar
            @source.currentChar
        end

        protected def peekChar
            @source.peekChar
        end

        abstract def extract
    end

    struct ErrorTk < Token
        
       protected def extract
           @text  = currentChar
           @ttype = TkType::ERROR
           @value = ErrCode::ILLEGAL_EXPRESSION
           nextChar
       end

    end

    struct StringTk < Token

        protected def extract
            nextChar
            while (currentChar != "\"") && (currentChar != EOF)
                @text += currentChar
                nextChar
            end
            if currentChar == "\"" 
                nextChar
                @ttype = TkType::STRING
            else
                @ttype = TkType::ERROR
                @value = ErrCode::STRING_MEETS_EOF
            end
        end
    end

    struct NumberTk < Token
        
        protected def extract
            
            extractNumbers
            if currentChar == "." && peekChar =~ /[0-9]/
                @text += currentChar
                nextChar
                if currentChar =~ /[0-9]/
                    extractNumbers
                    @value = @text.to_f
                    @ttype = TkType::FLOAT
                end
            else
                @value = @text.to_i
                @ttype = TkType::INT
            end

        end
        
        @[AlwaysInline]
        private def extractNumbers
            while currentChar =~ /[0-9]/
                @text += currentChar
                nextChar
            end
        end

    end

    struct EolTk < Token

        protected def extract
            @text = "\\n"
            @ttype = TkType::EOL
            nextChar
        end

    end

    struct EofTk < Token

        protected def extract
            @text  = "\\eof"
            @ttype = TkType::EOF
        end
        
    end

    struct IdentTk < Token

        protected def extract
            if (currentChar == "@") && (peekChar !~ /[_a-zA-Z]/)
                @ttype  = TkType::ERROR
                @text   = currentChar
                @value  = ErrCode::INVALID_ID
                nextChar
            else
                @text += currentChar
                nextChar
                while currentChar =~ /[_a-zA-Z0-9]/
                    @text += currentChar
                    nextChar
                end
                if @text[0] == '@'
                    @ttype = TkType::GLOBAL_ID
                else
                    ttype  = toTkType(@text)
                    @ttype = ttype ? ttype : TkType::LOCAL_ID
                end
            end
        end
    end

    struct SpecialCharTk < Token
        
        protected def extract
            @text += currentChar
            nextChar
            case @text
                when "$", "(", ")", "[", "]", "{", "}", ",", ";", "'"
                    # nextChar
                when ":","=", ">", "+", "-", "*", "^", "\\", "/", "%"
                    if currentChar == "="
                        @text += currentChar
                        nextChar
                    end
                when "<"
                    if currentChar == "=" || currentChar == ">" || currentChar == "<"
                        @text += currentChar
                        nextChar
                    end
                when "|"
                    if currentChar == "|"
                        @text += currentChar
                        nextChar
                    end
                when "&"
                    if currentChar == "&"
                        @text += currentChar
                        nextChar
                    end
                when "."
                    if currentChar == "." && peekChar == "."
                        @text += currentChar + nextChar
                        nextChar
                    elsif currentChar == "."
                        @text += currentChar
                        nextChar
                    end
                else
                  @ttype = TkType::ERROR
                  @value = ErrCode::ILLEGAL_EXPRESSION
            end
            @ttype = toTkType(@text).as(TkType) unless @ttype == TkType::ERROR
        end
        
    end

end