
# Copyright (c) 2017 Massimiliano Dal Mas
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

class LinCAS::Scanner < LinCAS::MsgGenerator
    
    def initialize(@source : Source)
        @msgHandler = MsgHandler.new
        @currentTk  = extractTk.as(Token)
    end

    def currentTk
        @currentTk
    end

    def nextTk
        @currentTk = extractTk
        @currentTk
    end

    def filename
        @source.getFilename
    end

    def messageHandler
        @msgHandler
    end

    protected def currentChar
        @source.currentChar
    end

    protected def nextChar
        @source.nextChar
    end

    protected def peekChar
        @source.peekChar
    end

    def lines
        @source.getLine
    end

    protected def extractTk
        skipWhiteSpaces
        case currentChar

            when /[\r\n]/
                return EolTk.new(@source)
            when /[@a-zA-Z_]/
                return IdentTk.new(@source)
            when /[0-9]/
                return NumberTk.new(@source)
            when EOF
                return EofTk.new(@source)
            when "\""
                return StringTk.new(@source)
            else
                return SpecialCharTk.new(@source) if isSpecialChar? currentChar
                return ErrorTk.new(@source)
        end
    end

    protected def skipWhiteSpaces

        while ((currentChar == " ") || (currentChar == "\t")) && (currentChar != EOF)
            nextChar
        end
        if (currentChar == "/") && (peekChar == "*")
            nextChar
            nextChar
            loop do
              break if (currentChar == "*") && (peekChar == "/")
              break if currentChar == EOF
              nextChar
            end 
            nextChar
            if currentChar == "/"
              nextChar
            elsif currentChar == EOF
                sendMsg(Msg.new(MsgType::COMMENT_MEETS_EOF_ERROR,
                                     ["Comment meets end-of-file",
                                      @source.getLine.to_s,
                                      @source.getPos.to_s,
                                      @source.getFilename]))
            end
        end
    end

end

