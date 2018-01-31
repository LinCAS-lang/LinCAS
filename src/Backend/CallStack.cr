
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

    struct StackFrame 
        
        getter filename
        getter line 
        getter callname
        property return_val
        property duplicated
        property block
        
        @return_val : Internal::Value
        @block : Node?
        def initialize(@filename : String,@line : Intnum, @callname : String)
            @varSet     = Hash(String,Internal::Value).new
            @return_val = Internal::Null
            @duplicated = false
            @block      = nil
        end

        def initialize(@filename : String,@line : Intnum, @varSet : Hash(String,Internal::Value))
            @callname   = "block"
            @return_val = Internal::Null
            @duplicated = false
            @block      = nil
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

        def to_unsafe
            return @varSet
        end
                
    end
    
    class CallStack < Array(StackFrame)
        
        MAX_CALLSTACK_DEPTH = 1100

        def initialize()
            super()
            @depth = 0
        end

        def pushFrame(filename,line,callname)
            Exec.lc_raise(LcSystemStackError,"Stack level too deep") if MAX_CALLSTACK_DEPTH == @depth
            @depth += 1
            self.push(StackFrame.new(filename,line,callname))
        end 

        def push_duplicated_frame
            frame = StackFrame.new(
                    self.last.filename,
                    self.last.line,
                    self.last.callname
            )
            frame.duplicated = true
            frame.block      = self.last.block
            self.push(frame)
        end

        def push_cloned_frame
            Exec.lc_raise(LcSystemStackError,"Stack level too deep") if MAX_CALLSTACK_DEPTH == @depth
            @depth += 1
            self.push(StackFrame.new(
                self.last.filename,
                self.last.line,
                self.last.to_unsafe.dup
            ))
        end

        def popFrame
            @depth -= 1
            return self.pop
        end

        def set_block(block : Node)
            tmp = self.pop
            tmp.block = block
            self.push(tmp)
        end

        def get_block
            self.last.block 
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
            count = 0
            return String.build do |io|
                self.reverse_each do |frame|
                    if !frame.duplicated
                        io << '\n' << "In: " << frame.callname << '\n'
                        io << "Line: " << frame.line << '\n'
                        io << "In: " << frame.filename << '\n'
                        count += 1
                    end
                    break if count == 8
                end 
                if count < @depth
                    io << '\n' << '\n'
                    io << " ... Other #{@depth - count} items"
                end
            end
        end

    end 

end