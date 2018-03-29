
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
  enum Code
    PUSHINT                
    PUSHFLO
    PUSHSTR 
    PUSHT 
    PUSHF 
    PUSHN  
    PUSHSELF  
    PUT_CLASS         
    PUT_MODULE 
    PUT_STATIC_METHOD
    PUT_INSTANCE_METHOD        
    CALL 
    CALL_WITH_BLOCK
    M_CALL         
    M_CALL_WITH_BLOCK 
    OPT_CALL_INIT         
    POPOBJ
    STOREL_0
    STOREL_1 
    STOREL_2
    STOREL                
    STOREG                  
    STOREC                         
    ARY_NEW                 
    IRANGE_NEW 
    ERANGE_NEW
    STRING_NEW             
    SYMC_NEW              
    SYMN_NEW                
    SYMF_NEW  
    MX_NEW              
    LOADV
    LOADL_0
    LOADL_1
    LOADL_2
    LOADL                   
    LOADG
    LOADC 
    GETC
    JUMP
    JUMPT
    JUMPF
    PRINT
    PRINTL
    PUSHDUP
    RETURN
    NEXT
    NEW_OBJ
    NOOP
    YIELD
    EQ_CMP

    LINE
    FILENAME
    LEAVE

    QUIT
    HALT
  end

  class Bytecode
    @nextc : Bytecode? = nil
    @lastc : Bytecode? = nil
    @text  = ""
    @argc  = 0
    @value = 0.as(Num)
    @opt_v = 0.as(Intnum)
    @jump  : Bytecode? = nil
    @line  = 0.as(Intnum)
    @method : LcMethod? = nil
    @block  : LcBlock?  = nil


    def initialize(@code : Code); end
    property code,nextc,text,argc,value,jump,lastc,line,method, block,opt_v
  end
end
