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
      INVOKE_BLOCK 

      PUT_CLASS 
      PUT_MODULE
      DEFINE_METHOD
      DEFINE_SMETHOD

      JUMPT
      JUMPF
      JUMP
      JUMPF_AND_POP
      CHECK_KW
      CHECK_MATCH

      SPLAT_ARRAY
      CONCAT_ARRAY
      ARRAY_APPEND
      MERGE_KW
      DUP_HASH

      MAKE_RANGE
      NEW_HASH
      NEW_ARRAY

      THROW

      LEAVE
      
      ] %}
        {{ins.id}} = {{i.id}}u64 << 32; {% i = i + 1%}
      {% end %}
    {% end %}
  end

  enum CatchType
    CATCH
    BREAK
    NEXT
  end

  class CatchTableEntry
    def initialize(
      @type : CatchType, 
      @start : Int32, 
      @end : Int32,
      @cont : Int32,
      @iseq = nil.as(ISeq?)
    )
    end

    getter type, start, :end, cont
    getter! iseq
  end

  ##
  # This is immutable. Its definition 
  # happens at compile time
  class CallInfo
    getter argc, name, explicit, block, splat, dbl_splat, block_param
    getter! kwarg

    def initialize(@name : String, 
      @argc : Int32, 
      @splat : Bool,
      @dbl_splat : Bool, 
      @kwarg : Array(String)?, 
      @explicit : Bool = true, 
      @block : ISeq? = nil,
      @block_param = false
     )
    end

    @[AlwaysInline]
    def has_kwargs?
      return !!kwarg? && !kwarg.empty?
    end

    # @[AlwaysInline]
    # def args_on_stack
    #   return @argc + (has_kwargs? ? @kwarg.not_nil!.size : 0)
    # end

    @[AlwaysInline]
    def argc_before_splat
      return @argc - 
             (@splat ? 1:0) - 
             (@dbl_splat ? 1:0) - 
             (kwarg? ? kwarg.size:0)
             # block param has already been captured by VM,
             # so no need to subtract it
    end
  end

  enum ISType
    PROGRAM
    METHOD
    BLOCK
    CLASS
    CATCH
  end

  class ISeq
    getter type, encoded, symtab, filename, line, catchtable, 
            object, jump_iseq, call_info, names, start_location
    property stack_size
    property! arg_info

    ##
    # @symtab should never be modified during compile time.
    # It must contain only local variable names
    def initialize(@type : ISType, @filename : String, @symtab : SymTable)
      # The real object is allocated only for method or block iseq
      @arg_info = nil.as ArgInfo?

      @encoded     = [] of IS
      @catchtable  = [] of CatchTableEntry
      @line        = [] of Location
      @object      = [] of LcVal
      @jump_iseq   = [] of ISeq
      @call_info   = [] of CallInfo
      
      # Internal symbol table for storing names such as
      # class names, method names to be defined. It should
      # contain a unique definition of a name.
      # use 'set_uniq_name' when compiling
      @names       = Array(String).new
      @stack_size  = 10
      @start_location = 0.as(Int32 | Int64)
    end

    def at(line : Int32 | Int64)
      @start_location = line
      self
    end

    class ArgInfo

      @argc       : Int32
      @optc       : Int32 
      @splat      : Int32 
      @kwargc     : Int32
      @dbl_splat  : Int32
      @block_arg  : Int32
      
      def initialize(
            @argc       , # counts only mandatory arguments
            @optc       , # if 0 avoids allocation of opt_table
            @splat      , # index
            @kwargc     ,
            @dbl_splat  , # index
            @block_arg    # index in the symbol table
          )
        # Opt table is organized like this:
        # sym table : [ lead ][ optional ][ splat ][ kwarg ][ dbl splat ][ blockarg ]
        # opt_table           [jump index][skip]
        # In which jump index points to the start of the instruction
        # to set the default value. Skip is the start of the instruction
        # to jump all the default value settings.
        # opt_table has an offset of '-lead' wrt the sym table 
        @opt_table  = nil.as Array(Int32)?
        @named_args = nil.as Hash(String, Tuple(UInt64, Bool))?
      end

      getter argc, optc, splat, kwargc, dbl_splat, block_arg
      property! opt_table, named_args

      def arg_simple?
        return @optc == 0 && 
        @splat == -1 && 
        @kwargc == 0 &&
        @dbl_splat == -1 &&
        @block_arg == -1
      end

      @[AlwaysInline]
      def splat?
        @splat >= 0
      end

      @[AlwaysInline]
      def dbl_splat?
        @dbl_splat >= 0
      end

      @[AlwaysInline]
      def kwargs?
        @kwargc > 0
      end

      @[AlwaysInline]
      def block_arg?
        @block_arg >= 0
      end
    end

    struct Location 
      getter sp, line
      def initialize(@sp : Int32 | Int64, @line : Int32 | Int64)
      end 
    end
  end
end
