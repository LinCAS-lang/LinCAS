
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

module LinCAS

    struct StackFrame 
        
        getter filename
        getter line 
        getter callname
        attr return_val
        
        @return_val : Internal::Value
        def initialize(@filename : String,@line : Intnum, @callname : String)
            @varSet     = Hash(String,Internal::Value).new
            @return_val = Internal::Null
        end
                
        def setVar(var, value)
            @varSet[var] = value
        end
        
        def getVar(var)
            return @varSet[var]?
        end
        
        def deleteVar(var)
            @varSet.delete(var)
        end
                
    end
    
    class CallStack < Array(StackFrame)
        
        MAX_CALLSTACK_DEPTH = 1500

        def initialize()
            super()
            @depth = 0
        end

        def pushFrame(filename,line,callname)
            # Internal.lc_raise() if MAX_CALLSTACK_DEPTH == @depth
            @depth += 1
            self.push(StackFrame.new(filename,line,callname))
        end 

        def popFrame
            @depth -= 1
            return self.pop
        end

        def setVar(var,value)
            self.last.setVar(var,value)
        end 

        def getVar(var)
            self.last.getVar(var)
        end 

        def deleteVar(var)
            self.last.deleteVar(var)
        end

        def getBacktrace
            ""
        end

    end 

end