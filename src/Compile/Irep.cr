# Copyright (c) 2020 Massimiliano Dal Mas
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
  enum IS : UInt64
    IS_MASK = UInt64::MAX << 32
    OP_MASK = UInt64::MAX >> 32
    {% begin %}
      {%i = 1%}

      {% for ins in %w[
      NOOP  

      SETLOCAL 
      SETLOCAL_0    
      SETLOCAL_1    
      SETLOCAL_2  

      GETLOCAL      
      GETLOCAL_0    
      GETLOCAL_1    
      GETLOCAL_2   

      SETINSTANCE_V 
      SETCLASS_V   

      GETINSTANCE_V 
      GETCLASS_V  

      STORECONST
      GETCONST

      POP     
      PUSHOBJ
      PUSH_TRUE 
      PUSH_FALSE 
      PUSH_SELF
      PUSH_NULL
      CALL
      CALL_NO_BLOCK 

      PUT_CLASS 
      PUT_MODULE

      JUMPT
      JUMPF
      JUMP
      JUMPF_AND_POP

      MAKE_RANGE

      LEAVE
      
      ] %}
        {{ins.id}} = {{i.id}}u64 << 32; {% i = i + 1%}
      {% end %}
    {% end %}
  end

  enum ISType
    PROGRAM
    METHOD
    BLOCK
    CLASS
  end

  class CatchT
  end

  class CallInfo
    getter argc, kwarg, name
    property explicit, block
    def initialize(@name : String, 
                   @argc : Int32, 
                   @kwarg : Array(String)?, 
                   @explicit : Bool = true, 
                   @block : ISeq? = nil
                  ) 
    end
  end

  class ISeq
    getter type, encoded, symtab, filename, line, catchtables, object, jump_iseq, call_info, names
    property args, opt_args, named_args, block_arg, stack_size

    @args : Array(String)?
    @opt_args : Array(Int32)?
    @named_args : Array(Tuple(String, Int32))?
    @block_arg : String?

    def initialize(@type : ISType, @filename : String, @symtab : SymTable)
      @args       = nil
      @opt_args   = nil
      @named_args = nil
      @block_arg  = nil

      @encoded     = [] of IS
      @catchtables = [] of CatchT
      @line        = [] of Location
      @object      = [] of LcVal
      @jump_iseq   = [] of ISeq
      @call_info   = [] of CallInfo
      @names       = [] of String
      @stack_size  = 10
    end

    struct Location 
      getter sp, line
      def initialize(@sp : Int32 | Int64, @line : Int32 | Int64)
      end 
    end
  end
end
