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
  class Compiler

    def initialize
      @stack_size = 0
      @max_stack_size = 0
      @compiler_state = [] of CompilerState
      @filename = ""
    end

    def compile(node : Program)
      @filename = node.filename
      body = node.body
      symtab = node.symtab
      iseq = ISeq.new(ISType::PROGRAM, @filename, symtab)
      compile_body(iseq, body)
      stack_decrease
      iseq.encoded << IS::LEAVE
      return iseq
    end

    def compile_each(iseq, node)
      case node
      when Noop
      when ClassNode
        compile_class(iseq, node)
      when ModuleNode
        compile_module(iseq, node)
      when FunctionNode
        compile_function(iseq, node)
      when Assign
        compile_assign(iseq, node)
      when If 
        compile_if(iseq, node)
      when Select
        compile_select(iseq, node)
      when While
        compile_while(iseq,node)
      when Until 
        compile_until(iseq,node)
      when For 
      when Call 
        compile_call(iseq, node)
      when And, Or 
        compile(iseq, node)
      when ConstDef
        compile_const_def(iseq, node)
      when Namespace 
        compile_namespace(iseq, node)
      when StringLiteral
      when TrueLiteral, FalseLiteral
        compile(iseq, node)
      when RangeLiteral
        compile_range(iseq, node)
      when ControlExpression
      when OpAssign
      when Variable 
        compile_variable(iseq, node)
      when ClassVar, InstanceVar
        compile_icvar(iseq, node)
      when NumberLiteral
        compile_number(iseq, node)
      when SymbolLiteral
      when Self
        compile_self(iseq, node)
      else
      end
    end
      

    def compile(iseq, node : Noop)
    end 

    def compile_class(iseq, node : ClassNode)
      encoded      = iseq.encoded
      symtab       = iseq.symtab
      namespace    = node.name
      superclass   = node.superclass 
      body         = node.body 
      set_line(iseq,node.location)

      # Name extraction
      name = namespace.names.last
      if namespace.names.size > 1
        compile_namespace(iseq, namespace, last: false)
      else 
        stack_increase
        encoded << IS::PUSH_SELF
      end

      # Put superclass on stack
      if superclass.is_a? Noop
        stack_increase
        encoded << IS::PUSH_NULL
      else 
        compile_namespace(iseq, superclass.as(Namespace))
      end
      symtab << name
      index = get_var_offset(symtab, name)
      encoded << (IS::PUT_CLASS | IS.new(index))

      # Compile class body
      class_iseq = ISeq.new(ISType::CLASS, @filename, node.symtab)
      compile_body(class_iseq, body)
      class_iseq.encoded << IS::LEAVE 

      # Set iseq offset to pick class body IS
      encoded << IS.new(iseq.jump_iseq.size.to_u64)
      iseq.jump_iseq << class_iseq
    end 
    
    def compile_module(iseq, node : ModuleNode)
      encoded      = iseq.encoded
      symtab       = iseq.symtab
      namespace    = node.name
      body         = node.body 
      set_line(iseq,node.location)

      # Name extraction
      name = namespace.names.last
      if namespace.names.size > 1
        compile_namespace(iseq, namespace, last: false)
      else
        stack_increase
        encoded << IS::PUSH_SELF
      end

      symtab << name
      index = get_var_offset(symtab, name)
      stack_decrease
      encoded << (IS::PUT_MODULE | IS.new(index))

      # Compile module body. The iseq type is considered as a class
      class_iseq = ISeq.new(ISType::CLASS, @filename, node.symtab)
      compile_body(class_iseq, body)
      class_iseq.encoded << IS::LEAVE 

      # Set iseq offset to pick module body IS
      encoded << IS.new(iseq.jump_iseq.size.to_u64)
      iseq.jump_iseq << class_iseq
    end

    def compile_function(iseq, node : FunctionNode)
      # Function instructions are emitted in 2 separated
      # instrucions:
      # > DEFINE_INS | Visibility
      # > Name Index | Jump Index

      encoded  = iseq.encoded
      names = iseq.names

      visibility = node.visibility
      receiver   = node.receiver
      name       = node.name

      set_line(iseq, node.location)

      if receiver 
        if receiver.is_a?(Variable) && receiver.name == "self"
          encoded << IS::PUSH_SELF
          stack_increase
        else
          compile_each(iseq, receiver)
        end
      end
      set_uniq_name names, name
      index = get_index_of(names, name)
      is    = receiver ? IS::DEFINE_SMETHOD : IS::DEFINE_METHOD
      encoded << (is | IS.new(visibility.value.to_u64))

      method = ISeq.new(ISType::METHOD, @filename, node.symtab)
      if params = node.params
        compile_method_params(method, params)
      else
        method.arg_info = ISeq::ArgInfo.new(0,0,-1,0,-1,-1)
      end
      compile_body(method, node.body)
      method.encoded << IS::LEAVE

      if index > UInt32::MAX || iseq.jump_iseq.size > UInt32::MAX
        # It is very unlikely the jump instructions or the name table size
        # are greater than UInt32::MAX
        lc_bug("Unsupported indexing greater than 32 bits")
      end
      encoded << (IS.new(index << 32) | IS.new(iseq.jump_iseq.size.to_u64))
      iseq.jump_iseq << method

      # VM may put on stack True or False according to the
      # success of the instruction. So no need to put another
      # object on stack
      #
      # encoded << IS::PUSH_OBJ | (iseq.object.size.to_u64)
      # iseq.object << Internal.build_symbol(name)
    end

    def compile_method_params(method : ISeq, params : Params)
      argv = params.args
      argc = argv.size - 
             params.optc -
             (params.splat_index >= 0 ? 1 : 0) -
             params.kwargc -
             (params.double_splat_index >= 0 ? 1 : 0) -
             (params.blockarg ? 1 : 0)

      block_index = params.blockarg ? params.args.size - 1 : -1

      arg_info = ISeq::ArgInfo.new(
        argc, 
        params.optc, 
        params.splat_index, 
        params.kwargc, 
        params.double_splat_index, 
        block_index
      )

      encoded  = method.encoded
      symtable = method.symtab

      # compile optional parameters
      if (optc = params.optc) > 0
        opt_table = [] of Int32
        count = argc + optc
        (argc...count).each do |i|
          arg     = argv[i]
          name    = arg.name
          default = arg.default_value.not_nil!
          opt_table << encoded.size
          compile_each(method, default)
          index =  get_index_of symtable, name
          encoded << (IS::SETLOCAL_0 | IS.new(index))
          # It's ok to pop the value from stack. If the
          # method body is empty there will be Null to
          # return
          encoded << IS::POP
        end
        opt_table << encoded.size # Jump all opt instructions
        arg_info.opt_table = opt_table
      end

      # compile kw args
      if (kwargc = params.kwargc) > 0
        start = argc + optc + (params.splat_index >= 0 ? 1 : 0)
        count = start + kwargc
        kw_table = Hash(String, Tuple(UInt64,Bool)).new
        (start...count).each do |i|
          arg     = argv[i]
          name    = arg.name
          default = arg.default_value
          index = get_index_of symtable, name
          if default
            kw_table[name] = {index, false}
            # Emit check if kw arg has been given by user
            # If so, jump the instructions
            set_line(method, arg.location)
            encoded << (IS::CHECK_KW | IS.new((i - start).to_u64))
            jump_index = encoded.size
            encoded << IS::JUMPF
            compile_each(method, default)
            encoded << (IS::SETLOCAL_0 | IS.new(index))
            # Jump to end of instructions
            encoded[jump_index] |= IS.new(encoded.size.to_u64)
          else
            kw_table[name] = {index, true}
          end
        end
        arg_info.named_args = kw_table
      end
      method.arg_info = arg_info
    end

    def compile_body(iseq, node : Body)
      encoded = iseq.encoded
      nodes = node.nodes
      if nodes.empty?
        set_line(iseq, node.location)
        encoded << IS::PUSH_NULL
        return
      end
      last = nodes.last
      nodes.each do |n|
        compile_each(iseq, n)
        unless n == last
          encoded.push IS::POP
          stack_decrease
        end
      end
    end

    def compile_assign(iseq, node : Assign)
      left = node.left 
      right = node.right
      compile_each(iseq, right)
      set_line(iseq, node.location)
      compile_store_local(iseq, left)      
    end

    protected def compile_store_local(iseq, node)
      encoded = iseq.encoded
      case node 
      when Variable  
        name  = node.name
        depth = node.depth 
        lc_bug("Negative depth") if depth < 0
        is = case depth 
        when 0 
          IS::SETLOCAL_0
        when 1 
          IS::SETLOCAL_1
        when 2 
          IS::SETLOCAL_2
        else 
          IS::SETLOCAL | IS.new(depth.to_u64)
        end
        index = get_var_offset iseq.symtab, name 
        if depth > 2 
          encoded << is 
          encoded << IS.new(index.to_u64)
        else 
          is = is | IS.new(index.to_u64)
          encoded << is 
        end
      when InstanceVar
        name  = node.name
        index = get_var_offset iseq.symtab, name
        encoded << (IS::SETINSTANCE_V | IS.new(index.to_u64))
      when ClassVar 
        name  = node.name
        index = get_var_offset iseq.symtab, name
        encoded << (IS::SETCLASS_V | IS.new(index.to_u64))
      else 
        lc_bug("Unhandled node #{node.class}") 
      end
      set_line(iseq, node)
    end

    def compile_block(node : Block, ci : CallInfo)
    end 

    def compile_if(iseq, node : If)
      condition = node.condition 
      then_branch = node.then_branch
      else_branch = node.else_branch

      encoded = iseq.encoded
      set_line(iseq, node.location)
      compile(iseq, condition)
      stack_decrease
      jump1 = encoded.size
      encoded.push IS::JUMPF
      compile_body(iseq, then_branch)
      jump2 = encoded.size
      if else_branch
        encoded << IS::JUMP
        encoded[jump1] |= IS.new(encoded.size.to_u64)
        compile_body(iseq, else_branch)
        encoded[jump2] |= IS.new(encoded.size.to_u64) 
      else 
        encoded[jump1] |= IS.new(encoded.size.to_u64)
      end
    end 

    def compile_select(iseq, node : Select)
    end 

    def compile_while(iseq, node : While)
      condition = node.condition 
      body      = node.body 
      encoded   = iseq.encoded
      set_line(iseq, node)

      # Pick the offset where the condition starts
      start_offset = encoded.size.to_u64
      compile_each(iseq, condition)

      # Pick the jumpf offset
      jumpf_offset = encoded.size
      encoded << IS::JUMPF

      # Compile body with state. At the end set the jump
      # to the condition evaluation
      state = with_state(State::Loop) { compile_body(iseq, body) }
      start_loop_jump = IS.new(start_offset)
      encoded << (IS::JUMP | start_loop_jump)

      end_loop_jump = IS.new(encoded.size.to_u64)
      encoded[jumpf_offset] |= end_loop_jump
      stack_decrease

      state.breaks.each do |offset|
        ensure_is(encoded[offset], IS::JUMP)
        encoded[offset] |= end_loop_jump
      end 
      state.nexts.each do |offset|
        ensure_is(encoded[offset], IS::JUMP)
        encoded[offset] |= start_loop_jump
      end
    end 

    def compile_until(iseq, node : Until)
      condition = node.condition 
      body      = node.body 
      encoded   = iseq.encoded
      # set_line(iseq, node)

      # Pick the starting offset for loop jump
      start_loop_jump = IS.new(encoded.size.to_u64)
      state = with_state(State::Loop) { compile_body(iseq, body) }
      compile_each(iseq, condition)
      
      encoded << (IS::JUMPF_AND_POP | start_loop_jump)
      stack_decrease

      end_loop_jump = IS.new(encoded.size.to_u64)
      state.breaks.each do |offset|
        ensure_is(encoded[offset], IS::JUMP)
        encoded[offset] |= end_loop_jump
      end 
      state.nexts.each do |offset|
        ensure_is(encoded[offset], IS::JUMP)
        encoded[offset] |= start_loop_jump
      end 
    end 

    def compile_for(iseq, node : For)
    end 

    def compile_call(iseq, node : Call)
      encoded   = iseq.encoded
      call_name = node.name
      if (receiver = node.receiver) && !receiver.is_a?(Noop)
        explicit = true
        compile_each(iseq, receiver)
      else
        explicit = false
        stack_increase
        encoded << IS::PUSH_SELF
      end
      compile_call_args(iseq, node.args)
      n_args = compile_named_args(iseq, node.named_args)
      
      argc = node.args ? node.args.not_nil!.size : 0
      call_info = CallInfo.new(call_name, argc, n_args, !!receiver)
      block_param = node.block_param
      case block_param
      when Block 
        compile_block(block_param, call_info)
      else
        if block_param.nil?
          if block = node.block
            compile_block(block, call_info) 
          end
        else
          compile_each(iseq, block_param)
        end
      end
      index = set_call_info(iseq, call_info)
      call_with_block = !!(block_param || node.block)
      is = case node.name
      # when "+"
      # when "-"
      # when "*"
      # when "/"
      # when "\\"
      # when "**"
      else
        call_with_block ? IS::CALL : IS::CALL_NO_BLOCK
      end
      op = IS.new(index)
      set_line(iseq, node.location)
      encoded << (is | op)
    end 

    @[AlwaysInline]
    def compile_call_args(iseq, args)
      return unless args
      args.each do |arg|
        compile_each(iseq, arg)
      end
    end 

    @[AlwaysInline]
    def compile_named_args(iseq, named_args)
      return unless named_args
      list = [] of String
      named_args.each do |n_arg|
        name, value = n_arg.name, n_arg.value 
        compile_each(iseq, value)
        case name
        when String
          list << name
        when StringLiteral
          # Not implemented yet
        end
      end
      return list
    end

    def compile(iseq, node : And)
      set_line(iseq, node)
      encoded = iseq.encoded
      compile_each(iseq, node.left)
      jump_offset = encoded.size
      encoded << IS::JUMPF
      compile_each(iseq, node.right)
      encoded[jump_offset] |= IS.new(encoded.size.to_u64)
    end 

    def compile(iseq, node : Or)
      set_line(iseq, node)
      encoded = iseq.encoded
      compile_each(iseq, node.left)
      jump_offset = encoded.size
      encoded << IS::JUMPT
      compile_each(iseq, node.right)
      encoded[jump_offset] |= IS.new(encoded.size.to_u64)
    end 

    def compile_const_def(iseq, node : ConstDef)
      names = iseq.names
      name   = node.name
      compile_each(iseq, node.exp)
      set_line(iseq,node)
      names << name
      index = get_index_of names, name
      is = IS::STORECONST | IS.new(index) 
      iseq.encoded << is
    end 

    def compile_namespace(iseq, node : Namespace, last = true)
      encoded = iseq.encoded
      symtab  = iseq.symtab
      names   = node.names
      if !last && names.size == 1
        # Nothing
      else
        set_line(iseq, node.location)
        size = names.size - 1
        stack_increase
        encoded << IS::PUSH_SELF
        names.each_with_index do |name, i|
          break if !last && i == size 
          symtab << name 
          index = get_var_offset(symtab, name)
          encoded << (IS::GETCONST | IS.new(index))
        end
      end
    end 

    def compile(iseq, node : StringLiteral)
    end

    def compile(iseq, node : TrueLiteral)
      stack_increase
      set_line(iseq, node.location)
      iseq.encoded << IS::PUSH_TRUE
    end

    def compile(iseq, node : FalseLiteral)
      stack_increase
      set_line(iseq, node.location)
      iseq.encoded << IS::PUSH_FALSE
    end

    def compile_range(iseq, node : RangeLiteral)
      left  = node.left 
      right = node.right
      inclusive = node.inclusive 
      compile_each(iseq, left)
      compile_each(iseq, right)
      flag = inclusive ? 1u64 : 0u64
      set_line(iseq, node)
      stack_decrease
      iseq.encoded << (IS::MAKE_RANGE | IS.new(flag))
    end 

    def compile(iseq, node : ControlExpression)
    end

    def compile_opassign(iseq, node : OpAssign)
      left   = node.left 
      right  = node.right 
      method = node.method  
      call   = Call.new(left, method, [right] of Node).at node.location
      case left 
      when Call 
        left.name += "="
        if left.args 
          left.args.not_nil! << call 
        else 
          left.args = [call] of Node 
        end 
        compile_call(iseq, left)
      when Variable, InstanceVar, ClassVar
        stack_decrease
        compile_call(iseq, call)
        compile_store_local(iseq, left)
      else 
        lc_bug("Unhandled OpAssign case")
      end     
    end

    def compile_variable(iseq, node : Variable)
      name  = node.name 
      set_line(iseq, node.location)
      if node.type.unknown?
      else
        stack_increase 
        level = node.depth
        lc_bug("Negative ldepth") if level < 0
        is = case level
        when 0
          IS::GETLOCAL_0
        when 1 
          IS::GETLOCAL_1
        when 2
          IS::GETLOCAL_2
        else 
          IS::GETLOCAL | IS.new(level.to_u64)
        end 
        location = get_var_offset(iseq.symtab, name)
        if level > 2
          iseq.encoded << is 
          iseq.encoded << IS.new(location)
        else 
          is |= IS.new(location)
          iseq.encoded << is
        end
      end
    end

    def compile_icvar(iseq, node : ClassVar | InstanceVar)
      symtab = iseq.symtab
      name   = node.name 
      symtab << name 
      index = get_index_of(symtab, name)
      is = node.is_a?(ClassVar) ? IS::GETCLASS_V : IS::GETINSTANCE_V
      iseq.encoded << (is | IS.new(index))
    end 

    def compile_number(iseq, node : NumberLiteral)
      value = node.value 
      type  = node.type 

      case type 
      when :INT 
        fits_in_i64 = value.to_i64?
        value = Internal.num2int fits_in_i64 ? fits_in_i64 : value.to_big_i  
      when :FLOAT 
        value = Internal.num2float(value.to_f64)
      when :COMPLEX 
        value = value.rstrip "i"
        value = Internal.complex_new(0f64, value.to_f64)
      end  
      index = set_obj_special(iseq, value.as(LcVal))
      is = IS::PUSHOBJ | IS.new(index)    
      set_line iseq, node.location 
      iseq.encoded.push is
    end 

    def compile(iseq, node : SymbolLiteral)
    end 

    def compile_self(iseq, node : Self)
      stack_increase
      set_line(iseq, node)
      iseq.encoded << IS::PUSH_SELF
    end

    def compile(iseq, node)
    end

    @[AlwaysInline]
    protected def get_index_of(symtab, name)
      index = symtab.index(name)
      return index.to_u64 if index 
      lc_bug("Variable offset not found") 
      0u64
    end

    protected def get_var_offset(symtab, name)
      while symtab 
        index = symtab.index(name)
        return index.to_u64 if index
        symtab = symtab.previous
      end 
      lc_bug("Variable offset not found") 
      0u64
    end 

    def set_obj_special(iseq, obj)
      object = iseq.object
      if index = object.index(obj)
        # nothing 
      else 
        index = object.size
        object << obj 
      end
      return index.to_u64
    end 

    def set_line(iseq, location : Location)
      line_ref   = iseq.line 
      if line_ref.empty? || line_ref.last.line != location.line
        line_ref << ISeq::Location.new(iseq.encoded.size, location.line)
      end
    end

    def set_line(iseq, location)
    end

    def stack_increase
      @stack_size += 1
      @max_stack_size = Math.max(@max_stack_size, @stack_size)
    end

    def stack_decrease
      @stack_size -= 1
    end

    private def set_call_info(iseq, ci)
      ciix = iseq.call_info.size.to_u64 
      iseq.call_info << ci 
      return ciix
    end 

    protected def ensure_is(is, type)
      # nothing
    end

    protected def with_state(type : State)
      @compiler_state << CompilerState.new(type)
      yield
      return @compiler_state.pop
    end

    private record CompilerState,
      state : State,
      breaks : Array(Int32) = [] of Int32,
      nexts  : Array(Int32) = [] of Int32

    private enum State 
      Loop 
      Block
    end
  end
end
