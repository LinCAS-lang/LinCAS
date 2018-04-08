
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
