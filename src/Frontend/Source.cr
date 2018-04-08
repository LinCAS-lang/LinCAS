
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

class LinCAS::Source

    def initialize(@reader : Reader)
        @line       = uninitialized String?
        @lineNum    = 0
        @currentPos = -2  
    end
  
    def getLine
        @lineNum
    end
  
    def getPos : (Int32 | Int64)
        @currentPos + 1
    end
  
    def currentChar
        if @line.nil? && (@currentPos != -2)
            return EOF
        elsif (@currentPos == -2) || (@currentPos > @line.as(String).size - 1)
            readLine
            return nextChar
        else
            return @line.as(String)[@currentPos].to_s
        end 
    end
  
    def nextChar
        @currentPos += 1
        currentChar
    end
  
    def peekChar
        currentChar
        return EOF if @line == nil
        nextPos = @currentPos + 1
        return (nextPos < @line.as(String).size - 1) ? @line.as(String)[nextPos].to_s : "\n"
    end
  
    def close
        @reader.close
    end
  
    protected def readLine
        @line = @reader.readLine
        @lineNum += 1
        @currentPos = -1
    end
  
    def getFilename
        @reader.getFilename
    end
end
