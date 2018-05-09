
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


module LinCAS
  enum Code
    PUSHINT             #         
    PUSHFLO             #
    PUSHSTR             #
    PUSHT               #
    PUSHF               #
    PUSHN               #
    PUSHSELF            #
    PUSHANS             #
    PUT_CLASS           #
    PUT_MODULE          #
    PUT_STATIC_METHOD   #
    PUT_INSTANCE_METHOD #       
    CALL                #
    CALL_WITH_BLOCK     #
    M_CALL              #        
    M_CALL_WITH_BLOCK   #
    OPT_CALL_INIT       #   
    POPOBJ              #
    STOREL_0            #
    STOREL_1            #
    STOREL_2            #
    STOREL              #          
    STOREG              #              
    STOREC              #                    
    ARY_NEW             #
    HASH_NEW            #   
    IRANGE_NEW          #
    ERANGE_NEW          #
    STRING_NEW          #            
    MX_NEW              #        
    LOADV               #
    LOADL_0             #
    LOADL_1             #
    LOADL_2             #
    LOADL               #              
    LOADG               #
    LOADC               #
    GETC                #
    JUMP                #
    JUMPT               #
    JUMPF               #
    PRINT               #
    PRINTL              #
    PUSHDUP             #
    RETURN              #
    NEXT                #
    NEW_OBJ             #
    NOOP
    YIELD               #
    EQ_CMP              #

    SET_C_T             #
    CLEAR_C_T           #

    LINE                #
    FILENAME            #
    LEAVE               #
    LEAVE_C             #

    NEW_SVAR            #
    NEW_SNUM            #
    NEW_FUNC            #
    S_SUM               #
    S_SUB               #
    S_PROD              #
    S_DIV               #
    S_POW               #

    QUIT                #
    HALT                #
  end

  class Bytecode
    @nextc : Bytecode? = nil
    @prev  : Bytecode? = nil
    @lastc : Bytecode? = nil
    @text  = ""
    @argc  = 0
    @value = 0.as(Num)
    @opt_v = 0.as(IntnumR)
    @jump  : Bytecode? = nil
    @line  = 0.as(IntnumR)
    @method : LcMethod? = nil
    @block  : LcBlock?  = nil
    @catch_t : CatchTable? = nil


    def initialize(@code : Code); end
    property code,nextc,text,argc,value,jump,lastc,line,method, 
             block,opt_v, catch_t,prev
  end
end
