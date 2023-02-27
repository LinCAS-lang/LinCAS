# Copyright (c) 2020-2023 Massimiliano Dal Mas
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
  module VmInsHelper
    include VmArgs

    macro vm_ensure_type(obj, type)
      lc_bug("VM expected #{{{type}}}, but got #{{{obj}}.class}") unless {{obj}}.is_a? {{type}}
    end

    # We already have call arguments on the stack that
    # are already available. Local variables are not 
    # kept on stack, therefore it will be the specialized
    # call-handler function's responsability to copy them
    # to the environment context.
    #
    # Since we need to clear the arg part after the call.
    # Therefore we need to remember what is the actual stack
    # pointer before the call args (and before pushing a new frame)
    macro set_stack_consistency_trace(offset)
      %sp = @sp - ({{offset}})
      debug "Setting trace: [sp: #{%sp}] [rsp: #{@sp}}]"
      @current_frame.sp = %sp
      @current_frame.real_sp = @sp
    end

    def vm_consistency_check
      if !@control_frames.empty?
        diff = @sp - @control_frames.last.real_sp
        if diff != 0
          lc_bug("Inconsistent VM stack. Cleaning difference: [%i]" % diff)
        end
      end
    end

    @[AlwaysInline]
    def vm_pc_consistency_check
      if !@current_frame.consistent_pc? @pc
        lc_bug("Inconsistent program counter detected")
      end
    end

    @[AlwaysInline]
    def vm_check_frozen_object(obj : LcVal)
      vm_check_frozen_object obj, "Can't modify frozen #{Internal.lc_typeof(obj)}"
    end

    @[AlwaysInline]
    def vm_check_frozen_object(obj : LcVal, msg : String)
      if has_flag obj, FROZEN
        lc_raise(LcFrozenError, msg)
      end
    end

    @[AlwaysInline]
    private def vm_new_env(iseq : ISeq, context : LcClass, calling : VM::CallingInfo, flags)
      return VM::Environment.new(iseq.symtab.size, context, flags, calling.block)
    end

    @[AlwaysInline]
    private def vm_new_env(iseq : ISeq, context : LcClass, calling : VM::CallingInfo, previous : VM::Environment, flags)
      return VM::Environment.new(iseq.symtab.size, context, flags, calling.block, previous)
    end

    protected def vm_setlocal(offset, level, value : LcVal)
      env = @current_frame.env
      level.times do
        env = env.previous.not_nil!
      end
      env[offset] = value
    end 

    @[AlwaysInline]
    protected def vm_setlocal_0(offset, value : LcVal)
      @current_frame.env[offset] = value
    end

    @[AlwaysInline]
    protected def vm_setlocal_1(offset, value : LcVal)
      @current_frame.env.previous.not_nil![offset] = value
    end

    @[AlwaysInline]
    protected def vm_setlocal_2(offset, value : LcVal)
      env = @current_frame.env.previous.not_nil!.previous.not_nil!
      env[offset] = value
    end

    protected def vm_getlocal(offset, level)
      env = @current_frame.env
      level.times do
        env = env.previous.not_nil!
      end
      env[offset]
    end 

    @[AlwaysInline]
    protected def vm_getlocal_0(offset)
      @current_frame.env[offset]
    end

    @[AlwaysInline]
    protected def vm_getlocal_1(offset)
      @current_frame.env.previous.not_nil![offset]
    end

    @[AlwaysInline]
    protected def vm_getlocal_2(offset)
      env = @current_frame.env.previous.not_nil!.previous.not_nil!
      env[offset]
    end

    @[AlwaysInline]
    protected def vm_setinstance_v(name : String, me : LcVal, value : LcVal)
      vm_check_frozen_object me
      me.data[name] = value
    end

    @[AlwaysInline]
    protected def vm_getinstance_v(name : String, me : LcVal)
      return (value = me.data[name]?) ? value : Null
    end

    @[AlwaysInline]
    private def self_or_class(obj : LcVal)
      klass = obj
      if !obj.is_a? LcClass
        klass = obj.klass
      end
      return klass.as LcClass
    end

    @[AlwaysInline]
    protected def find_cvar_def(klass : LcClass, name : String)
      found = false
      while klass && !klass.data[name]?
        klass = klass.parent
      end
      return klass
    end

    @[AlwaysInline]
    protected def vm_setclass_v(name : String, me : LcVal, value : LcVal)
      base = self_or_class me
      klass = find_cvar_def(base, name) || base
      klass.data[name] = value
    end

    @[AlwaysInline]
    protected def vm_getclass_v(name : String, me : LcVal)
      base = self_or_class me
      klass = find_cvar_def(base, name)
      if klass
        return klass.data[name]
      end
      lc_raise(LcNameError, "Uninitialized class variable #{name} in #{Internal.class_path(base)}")
    end

    protected def vm_storeconst(name : String, me : LcVal, value : LcVal)
      base = self_or_class me
      if !base.namespace.find name, const: true
        Internal.lc_define_const(base, name, value)
      else
        lc_raise(LcNameError, "Constant #{name} already defined")
      end
    end

    ##
    # TODO: what if we have this case:
    #```
    # class C { const CONST := 10}
    # c = C
    # printl c::CONST
    # ```
    # for now `c` is assumed to be another constant
    protected def vm_getconst(name : String, me : LcVal)
      base = self_or_class me
      const = Internal.lc_seek_const(base, name)
      return const if const
      lc_raise(LcNameError, "Uninitialized const #{name}")
    end

    protected def vm_capture_block(ci : CallInfo)
      block = ci.block 
      if block 
        return iseq_to_captured_block(block)
      else
        bh = topn(0)
        if bh.is_a? LcProc 
          return bh
        else 
          # lc_raise(.., "Wrong argument type #{type_of(bh)} (expected Proc)")
        end
      end
      nil
    end

    @[AlwaysInline]
    private def iseq_to_captured_block(block : ISeq)
      return LcBlock.new(block, @current_frame.me, @current_frame.env)
    end

    private def vm_no_method_found(ci : CallInfo, calling : VM::CallingInfo, cc : VM::CallCache)
      raise  "No method found"
      case cc.m_missing_status
      when 0
      when 1
      when 2
      end
    end

    ##
    # Performs the actual call of a method
    protected def vm_call(ci : CallInfo, calling : VM::CallingInfo)
      debug("Seeking method '#{ci.name}' in #{calling.me.klass.name}")
      cc = Internal.seek_method(calling.me.klass, ci.name, ci.explicit)
      vm_no_method_found(ci, calling, cc) if cc.method.nil?
      method = cc.method.not_nil!

      return case method.type 
      when .internal?
        vm_call_internal(method, ci, calling)
      when .user?
        vm_call_user(method, ci, calling)
      # when .python?
      # when .proc?
      else
        lc_bug("Invalid method type received")
        Null
      end
    end 

    private def vm_call_internal(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo)
      vm_setup_args_internal_or_python(ci, calling, method.arity)
      argv = vm_collect_args(method.arity, calling)

      set_stack_consistency_trace(calling.argc + 1)
      vm_push_control_frame(calling.me, method.owner, calling.block, VM::VmFrame::ICALL_FRAME)
      val = call_internal_special(method, argv)

      push val
      vm_pop_control_frame
    end

    private def call_internal_special(method : LcMethod, argv)
      case method.arity
      when 0
        method.code.as(LcProc).call(argv[0])
      when 2
        argv = argv.as(T3)
        method.code.as(LcProc).call(argv[0], argv[1], argv[2])
      when 3
        argv = argv.as(T4)
        method.code.as(LcProc).call(argv[0], argv[1], argv[2], argv[3])
      else
        argv = argv.as(T2)
        method.code.as(LcProc).call(argv[0], argv[1])
      end
    end

    private def vm_call_user(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo)
      iseq = method.code.as(ISeq)
      env = vm_new_env(iseq, method.owner, calling, VM::VmFrame::UCALL_FRAME)
      offset = vm_setup_iseq_args(env, iseq.arg_info, ci, calling)
      
      set_stack_consistency_trace(calling.argc + 1)
      vm_push_control_frame(calling.me, iseq, env, VM::VmFrame::UCALL_FRAME)
      # no need to update sp in the frame. When another call happens, 
      # it will be saved automatically
      @pc += offset
    end 

    private def vm_call_python()
    end

    protected def vm_invoke_block(ci : CallInfo, calling : VM::CallingInfo)
      block = vm_get_block
      if block
        p_env = block.env
        env = vm_new_env(block.iseq, p_env.context, calling, p_env, VM::VmFrame::BLOCK_FRAME)
        iseq_offset = vm_setup_block_args(env, block.iseq.arg_info, ci, calling)
        
        set_stack_consistency_trace(calling.argc)
        vm_push_control_frame(
          block.me,
          block.iseq,
          env,
          env.frame_type
        )
        @pc += iseq_offset
      else
        lc_raise(LcArgumentError, "No block given (yield)")
      end
    end

    private def vm_search_const_under(klass : LcClass, name : String)
      const = Internal.lc_seek_const klass, name, exclude: true, recurse: false
      return const if const
      if klass == Internal.lc_object
        parent = klass
        while parent = parent.parent
          const = Internal.lc_seek_const klass, name, exclude: true, recurse: false
          return const if const
        end
      end
    end

    protected def vm_putclass(me : LcVal, name : String, parent : LcVal, iseq : ISeq)
      context = self_or_class me

      if !(parent.is_a?(LcClass) && parent.is_class?) && parent != Null
        lc_raise(LcTypeError, "Parent must be a class (#{Internal.lc_typeof(parent)} given)")
      end

      c_def = vm_search_const_under context, name
      if c_def.is_a?(LcClass) && c_def.is_class?
        vm_check_frozen_object c_def, "Can't reopen a frozen class"
        unless parent == Null
          lc_raise LcTypeError, "Superclass missmatch for #{name}"
        end
      elsif c_def.nil?
        if parent.is_a?(LcClass)
          c_def = Internal.lc_build_user_class(name, context.namespace, parent)
        else
          c_def = Internal.lc_build_user_class(name, context.namespace)
        end
      else
        lc_raise LcTypeError, "'#{name}' is not a class"
      end
      set_stack_consistency_trace 0
      vm_push_control_frame(c_def.not_nil!, c_def.not_nil!.as(LcClass), iseq, VM::VmFrame::CLASS_FRAME)
    end

    protected def vm_putmodule(me : LcVal, name : String, iseq : ISeq)
      context = me.is_a?(LcClass) ? me.as(LcClass) : me.klass
      m_def = vm_search_const_under context, name
      if m_def.is_a?(LcClass) && m_def.is_module?
        vm_check_frozen_object m_def, "Can't reopen a frozen module"
      elsif m_def.nil?
        m_def = Internal.lc_build_user_module(name, context.namespace)
      else
        lc_raise LcTypeError, "'#{name}' is not a module"
      end
      set_stack_consistency_trace 0
      vm_push_control_frame(m_def.not_nil!, m_def.not_nil!.as(LcClass), iseq, VM::VmFrame::CLASS_FRAME)
    end

    protected def vm_define_method(visibility : Int32, receiver : LcVal?, name : String, iseq : ISeq, singleton : Bool)
      visibility = FuncVisib.from_value visibility # raises exception if incorrect
      
      if !singleton
        me = @current_frame.me
        receiver = me.is_a?(LcClass) ? me : me.klass
      else
        receiver = receiver.not_nil!.klass # Todo: ensure not frozen class
      end
      debug("Defining method '#{name}' in #{receiver.name}")
      method = Internal.lc_def_method(name, iseq, visibility)
      Internal.lc_add_method_with_owner(receiver, name, method)
      push LcTrue
    end

    @[AlwaysInline]
    protected def vm_jumpt(condition : LcVal, offset : UInt64)
      if !{LcFalse, Null}.includes? condition
        @pc = @current_frame.pc_bottom + offset
        return true
      end
      return false
    end
    
    @[AlwaysInline]
    protected def vm_jumpf(condition : LcVal, offset : UInt64)
      if {LcFalse, Null}.includes? condition
        @pc = @current_frame.pc_bottom + offset
        return true
      end
      return false
    end

    @[AlwaysInline]
    protected def vm_jump(offset : UInt64)
      @pc = @current_frame.pc_bottom + offset
    end

    @[AlwaysInline]
    protected def vm_jumpf_and_pop(condition : LcVal, offset : UInt64)
      pop if vm_jumpf(condition, offset)
    end

    @[AlwaysInline]
    protected def vm_merge_kw(hash1 : LcVal, hash2 : LcVal)
      vm_ensure_type hash1, Internal::LcHash
      Internal.lc_hash_o_merge(hash1, hash2) # Check if kwsplat is a hash is done here
    end

    protected def vm_splat_array(value : LcVal)
      if value.is_a? Internal::LcArray
        return Internal.lc_ary_clone(value)
      else
        # TODO: check if value implements to_a
        return Internal.build_ary(1, value)
      end
    end

    @[AlwaysInline]
    protected def vm_ary_concat(a1 : LcVal, a2 : LcVal)
      # This instruction is mostry used for internal operations,
      # so we must be sure the compiler instructions place a real
      # array as first argument
      vm_ensure_type a1, Internal::LcArray
      lc_bug "Missing implementation of Array#concat!" # TODO
    end

    protected def vm_array_append(array : LcVal, value : LcVal)
      vm_ensure_type array, Internal::LcArray
      array = lc_recast(array, Ary)
      array << value
    end

    @[AlwaysInline]
    protected def vm_check_kw(index : UInt64)
      return (@current_frame.env.kw_bit & (1 << index)).zero? ? LcFalse : LcTrue
    end

    @[AlwaysInline]
    protected def vm_dup_hash(hash : LcVal)
      # Same thing as vm_ary_concat
      vm_ensure_type hash, Internal::LcHash
      return Internal.lc_hash_clone hash
    end

    @[AlwaysInline]
    protected def vm_make_range(v1 : LcVal, v2 : LcVal, inclusive : UInt64)
      inc = !(inclusive & 0x01).zero?
      return Internal.build_range(v1, v2, inc)
    end

    @[AlwaysInline]
    protected def vm_new_hash(size : UInt64)
      hash = Internal.build_hash
      depth = size.to_i64 * 2 - 1
      size.times do
        Internal.lc_hash_set_index(hash, topn(depth), topn(depth - 1))
        depth -= 2
      end
      @sp -= size * 2
      return hash
    end

    @[AlwaysInline]
    protected def vm_new_array(size : UInt64)
      size = size.to_i64
      array = Internal.build_ary(size).as(Internal::LcArray)
      @sp -= size
      array.ptr.copy_from(@stack.ptr + @sp, size)
      array.size = size
      return array.as(LcVal)
    end

    #######################################
    # __     ____  __      _    ____ ___  #
    # \ \   / /  \/  |    / \  |  _ \_ _| #
    #  \ \ / /| |\/| |   / _ \ | |_) | |  #
    #   \ V / | |  | |  / ___ \|  __/| |  #
    #    \_/  |_|  |_| /_/   \_\_|  |___| #
    ####################################### 

    def call_proc(proc : Internal::LCProc, argv : Ary)
      return Null
    end

    def call_method(method : Internal::Method, argv : Ary | Array(LcVal))
      return Null
    end

    def lc_call_fun(receiver :  LcVal, method : String, *args)
      return Null 
    end

    def lc_yield(*args :  LcVal)
      Null
    end

    def lc_raise(code,msg)
      Null
    end

    def lc_raise(error :  LcVal)
      Null
    end 

    def get_block 
      vm_get_block
    end

    def get_current_namespace : NameTable
      main_namespace = @stack[0].klass.namespace
      @control_frames.reverse_each do |frame|
        if frame.flags.includes?(VM::VmFrame::MAIN_FRAME) 
          return main_namespace 
        elsif frame.flags.includes?(VM::VmFrame::CLASS_FRAME)
          obj = topn(frame.real_sp)
          if !obj.is_a? LcClass
            break
          end 
          return obj.as(LcClass).namespace
        end
      end
      lc_bug("VM failed to retrieve current namespace")
      return main_namespace # Unreachable. Just for inference purposes
    end

    def error?
      lc_bug("Deprecated error handling used")
      false 
    end
    
  end 
end