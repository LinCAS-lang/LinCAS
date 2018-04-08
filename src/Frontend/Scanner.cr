
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
        if currentChar == "#"
            while currentChar != "\n" && currentChar != EOF
                nextChar
            end
        end
    end

end

