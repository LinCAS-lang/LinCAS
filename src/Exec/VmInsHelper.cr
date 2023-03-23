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
    # Since we need to clear the arg part after the call
    # we need to remember what is the actual stack
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
        lc_raise(Internal.lc_frozen_err, msg)
      end
    end

    @[AlwaysInline]
    private def vm_new_env(iseq : ISeq, context : VM::Context, previous : VM::Environment, flags)
      return VM::Environment.new(iseq.symtab.size, context, flags, nil, previous)
    end
    
    @[AlwaysInline]
    private def vm_new_env(iseq : ISeq, context : VM::Context, calling : VM::CallingInfo, flags)
      return VM::Environment.new(iseq.symtab.size, context, flags, calling.block)
    end

    @[AlwaysInline]
    private def vm_new_env(iseq : ISeq, context : VM::Context, calling : VM::CallingInfo, previous : VM::Environment, flags)
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

    # To set or get a class variable we need to know in which class
    # of the inheritance chain it was defined. If no definition is
    # found, the method returns nil
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
      lc_raise(Internal.lc_name_err, "Uninitialized class variable #{name} in #{Internal.class_path(base)}")
    end

    protected def vm_storeconst(name : String, me : LcVal, value : LcVal)
      base = self_or_class me
      if !base.namespace.find name, const: true
        Internal.lc_define_const(base, name, value)
      else
        lc_raise(Internal.lc_name_err, "Constant #{name} already defined")
      end
    end

    # The behavior we wish to have is the following:
    # When a method references a constant, we want to look for from
    # the class and its ancestores the method is defined in and in the
    # class upper lexical scopes. For example:
    # ```
    # class MyClass {
    #   const MyConst := 10
    #   let get_myconst {
    #     return MyConst
    #   }
    # }
    # class MyClass2 inherits MyClass {
    #   const MyConst := 100
    # }
    #
    # my_obj := new MyClass2
    # my_obj.get_myconst  #=> should return 10 and not 100
    # ```
    private def vm_dispatch_const(orig_class : LcVal, name : String, allow_null : Bool)
      if orig_class == Null && allow_null
        # current lexical scope
        base = get_class_ref
        if base.type.metaclass?
          # we need to find the real class this metaclass belongs to
          context_class = self_or_class @current_frame.me
          while context_class && context_class.klass != base
            context_class = context_class.parent
          end
          if context_class
            base = context_class
          else
            lc_bug("Vm failed to resolve the lexical scope for constant #{name}")
          end
        end
      else
        unless orig_class.is_a? LcClass
          lc_raise(Internal.lc_type_err, "#{Internal.lc_typeof(orig_class)} is not a class/module")
        end
        base = orig_class.as(LcClass)
      end
      return Internal.lc_seek_const(base, name)
    end


    ##
    # TODO: what if we have this case:
    #```
    # class C { const CONST := 10}
    # c = C
    # printl c::CONST
    # ```
    # for now `c` is assumed to be another constant
    @[AlwaysInline]
    protected def vm_getconst(orig_class : LcVal, name : String, allow_null : Bool)
      const = vm_dispatch_const(orig_class, name, allow_null)
      return const if const
      lc_raise(Internal.lc_name_err, "Uninitialized const #{name}")
    end

    protected def vm_capture_block(ci : CallInfo)
      block = ci.block 
      if block 
        return iseq_to_captured_block(block)
      else
        bh = pop
        if bh.is_a? Internal::LCProc 
          return bh
        else 
          lc_raise(Internal.lc_arg_err, "Wrong argument type #{Internal.lc_typeof(bh)} (expected Proc)")
        end
      end
      nil
    end

    @[AlwaysInline]
    private def iseq_to_captured_block(block : ISeq)
      return LcBlock.new(block, @current_frame.me, @current_frame.env)
    end

    private def vm_no_method_found(ci : CallInfo, calling : VM::CallingInfo, cc : VM::CallCache)
      msg = 
      case cc.m_missing_status
      when 0 #  undefined
        "Undefined method `#{ci.name}' for #{Internal.lc_typeof(calling.me)}"
      when 1 # protected
        "Protected method `#{ci.name}' called for #{Internal.lc_typeof(calling.me)}"
      when 2 # private
        "Private method `#{ci.name}' called for #{Internal.lc_typeof(calling.me)}"
      else
        "Undefined method `#{ci.name}'"
      end
      lc_raise(Internal.lc_nomet_err, msg)
    end

    private def has_valid_cc?(ci : CallInfo, calling : VM::CallingInfo)
      return (cc = ci.cc) && 
          cc.klass == calling.me.klass && 
          !cc.method.not_nil!.flags.invalidated? &&
          cc.orig_serial == cc.method.not_nil!.serial
    end

    # Here it gets a bit tricky. What we wish to happen is:
    # * if a method is private, it must be visible only within the class
    #   of definition (can't be called from the instance)
    # * if a method is protected, it is visible within the class of definition
    #   and to all it's children. (can't be called from the instance)
    # * public methods can be called anywhere.
    # * if the call is in the format `self.my_method`, this enforces
    #   the method lookup from the class of the instance the method was invoked
    #   on and not from the class of definition. However, protected or
    #   private methods should be allowed if they meet the rules above
    @[AlwaysInline]
    private def vm_dispatch_method(ci : CallInfo, calling : VM::CallingInfo)
      if has_valid_cc? ci, calling
        return ci.cc.not_nil!
      end
      context = get_class_ref
      _self = calling.me
      if !(explicit = ci.explicit)
        # The call is in the format `foo`. If this happens within a user method
        # scope, then we use such lexical scope to search the method. Otherwise,
        # we use the class of the object that is currently executing.
        if @current_frame.flags.includes? VM::VmFrame.flags(UCALL_FRAME)
          debug("Dispatching method using context #{context.name}##{ci.name}")
          klass = context
        else
          klass = _self.klass
          debug("Dispatching method in object class #{klass.name}##{ci.name}")
        end
      else
        # In this case the call is in the format `a.foo`. The method is searched from
        # the class of `a` and allows protected and private methods (explicit)only if
        # `a` is an instance or sub instance of the current lexical scope
        klass = _self.klass
        explicit = !(_self == context || Internal.lincas_obj_is_a(_self, context))
        debug("Dispatching #{klass.name}##{ci.name}; explicit: #{explicit} (orig: #{ci.explicit})")       
      end
      return Internal.seek_method(klass, ci.name, explicit)
    end

    ##
    # Performs the actual call of a method. It is responsible of dispatching it
    # and call it
    @[AlwaysInline]
    protected def vm_call(ci : CallInfo, calling : VM::CallingInfo, flags = VM::VmFrame::FLAG_NONE)
      debug("Seeking method '#{ci.name}' in #{calling.me.klass.name}")
      cc = vm_dispatch_method(ci, calling)
      vm_no_method_found(ci, calling, cc) if cc.method.nil?
      method = cc.method.not_nil!
      unless ci.cc == cc
        cc.klass = calling.me.klass
        ci.cc  = cc # store the call cache for next call
        method.cached!
      end
      vm_call_any(method, ci, calling, flags)
      return method.flags
    end 

    @[AlwaysInline]
    private def vm_call_any(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo, flags : VM::VmFrame)
      case method.flags 
      when .internal?
        vm_call_internal(method, ci, calling, flags)
      when .user?
        vm_call_user(method, ci, calling, flags)
      when .attr_reader?
        vm_call_getter(method, ci, calling)
      when .attr_writer?
        vm_call_setter(method, ci, calling)
      # when .python?
      # when .proc?
      else
        lc_bug("Invalid method type received")
        Null
      end
    end

    private def vm_call_internal(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo, flags : VM::VmFrame)
      vm_setup_args_internal_or_python(ci, calling, method.arity)
      argv = vm_collect_args(method.arity, calling)
      flags |= VM::VmFrame.flags(ICALL_FRAME, FLAG_LOCAL)
      if ci.has_kwargs? || ci.dbl_splat
        flags |= VM::VmFrame::FLAG_KEYWORDS
      end
      set_stack_consistency_trace(calling.argc + 1)
      vm_push_control_frame(calling.me, method, calling.block, flags)

      # This argc check is done here instead of 'vm_setup_args_internal_or_python'
      # since we need to provide a good backtrace in case of failure. To do so
      # we need to have the call frame in place, and this happens in the line above.
      if (arity = method.arity) >= 0 # Likely
        min_argc = max_argc = arity
      else
        min_argc = arity - 1
        max_argc = UNLIMITED_ARGUMENTS
      end
      vm_check_arity(min_argc, max_argc, calling.argc)

      val = call_internal_special(method, argv)

      push val
      vm_pop_control_frame
    end

    private def call_internal_special(method : LcMethod, argv)
      case method.arity
      when 0
        method.code.as(LcProc).call(argv[0])
      when 2
        method.code.as(LcProc).call(argv[0], argv[1], argv[2])
      when 3
        method.code.as(LcProc).call(argv[0], argv[1], argv[2], argv[3])
      else
        method.code.as(LcProc).call(argv[0], argv[1])
      end
    end
    
    private def vm_call_user(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo, flags : VM::VmFrame)
      iseq = method.code.as(ISeq)
      flags |= VM::VmFrame.flags(UCALL_FRAME, FLAG_LOCAL)
      env = vm_new_env(iseq, method, calling, flags)
      offset = vm_setup_iseq_args(env, iseq.arg_info, ci, calling)
      
      set_stack_consistency_trace(calling.argc + 1)
      vm_push_control_frame(calling.me, iseq, env, env.frame_type)
      # no need to update sp in the frame. When another call happens, 
      # it will be saved automatically (set_stack_consistency_trace)
      @pc += offset
    end 

    @[AlwaysInline]
    private def vm_call_getter(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo)
      vm_check_arity(0, 0, calling.argc)
      @stack[@sp - 1] = vm_getinstance_v(method.code.as(String), calling.me)
    end

    @[AlwaysInline]
    private def vm_call_setter(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo)
      vm_check_arity(1, 1, calling.argc)
      @sp -= 1
      @stack[@sp - 1] = @stack[@sp]
      vm_setinstance_v(method.code.as(String), calling.me, topn(0))
    end

    private def vm_call_python()
    end

    protected def vm_invoke_block(ci : CallInfo, calling : VM::CallingInfo, flags = VM::VmFrame::FLAG_NONE)
      block = vm_get_block
      if block
        p_env = block.env
        env = vm_new_env(block.iseq, p_env.context, calling, p_env, VM::VmFrame::BLOCK_FRAME | flags)
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
        lc_raise(Internal.lc_localjmp_err, "No block given (yield)")
      end
    end

    protected def vm_call_or_const(ci : CallInfo, calling : VM::CallingInfo, is : IS)
      const = method = nil
      case is
      when .call_or_const?
        method = vm_dispatch_method(ci, calling).method
        unless method
          const = vm_dispatch_const(Null, ci.name, true)
        end
      when .const_or_call?
        const = vm_dispatch_const(Null, ci.name, true)
        unless const
          method = vm_dispatch_method(ci, calling).method
        end
      end

      if const
        push const
      elsif method
        push calling.me # we need to have self on stack
        vm_call_any(method, ci, calling, VM::VmFrame::FLAG_NONE)
      else
        case is
        when .call_or_const?
          part = "method or constant"
        when .const_or_call?
          part = "constant or method"
        end
        msg = "Undefined #{part} `#{ci.name}'"
        lc_raise(Internal.lc_name_err, msg)
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
        lc_raise(Internal.lc_type_err, "Parent must be a class (#{Internal.lc_typeof(parent)} given)")
      end

      c_def = vm_search_const_under context, name
      if c_def.is_a?(LcClass) && c_def.is_class?
        vm_check_frozen_object c_def, "Can't reopen a frozen class"
        unless parent == Null
          lc_raise Internal.lc_type_err, "Superclass missmatch for #{name}"
        end
      elsif c_def.nil?
        if parent.is_a?(LcClass)
          c_def = Internal.lc_build_user_class(name, context.namespace, parent)
        else
          c_def = Internal.lc_build_user_class(name, context.namespace)
        end
      else
        lc_raise Internal.lc_type_err, "'#{name}' is not a class"
      end
      set_stack_consistency_trace 0
      vm_push_control_frame(c_def.not_nil!, c_def.not_nil!.as(LcClass), iseq, VM::VmFrame.flags(CLASS_FRAME, FLAG_LOCAL))
    end

    protected def vm_putmodule(me : LcVal, name : String, iseq : ISeq)
      context = me.is_a?(LcClass) ? me.as(LcClass) : me.klass
      m_def = vm_search_const_under context, name
      if m_def.is_a?(LcClass) && m_def.is_module?
        vm_check_frozen_object m_def, "Can't reopen a frozen module"
      elsif m_def.nil?
        m_def = Internal.lc_build_user_module(name, context.namespace)
      else
        lc_raise Internal.lc_type_err, "'#{name}' is not a module"
      end
      set_stack_consistency_trace 0
      vm_push_control_frame(m_def.not_nil!, m_def.not_nil!.as(LcClass), iseq, VM::VmFrame.flags(CLASS_FRAME, FLAG_LOCAL))
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

    protected def vm_check_match(type : UInt64, a : LcVal, b : LcVal)
      case type
      when 0 # catch
        if !(Internal.lincas_obj_is_a(b, Internal.lc_module))
          lc_raise(Internal.lc_type_err, "Class or module required for catch statement")
        end
        return Internal.val2bool(Internal.lincas_obj_is_a(a, b))
      else
        LcFalse
      end
    end

    @[AlwaysInline]
    protected def vm_dup_hash(hash : LcVal)
      # Same thing as vm_ary_concat
      vm_ensure_type hash, Internal::LcHash
      return Internal.lc_hash_clone hash
    end

    protected def vm_str_concat(count : UInt64)
      @sp -= count
      return Internal.lincas_concat_literals(count) do |i|
        @stack[@sp + i]
      end
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

    protected def vm_new_object(ci : CallInfo, calling : VM::CallingInfo)
      argc = calling.argc
      klass = topn(argc).as LcClass
      if !klass.is_class?
        lc_raise(Internal.lc_type_err, "Object type must be a class (#{Internal.lc_typeof(klass)} given)")
      end

      obj = Internal.lc_new_object(klass)
      @stack[@sp - argc - 1] = calling.me = obj # we replace the class with the actual object

      # now we can call initialize if there is any
      cc = vm_dispatch_method(ci, calling)
      if init = cc.method
        call_method_with_handled_return(init, ci, calling)
        push calling.me
      else
        vm_no_method_found(ci, calling, cc)
      end
    end

    protected def vm_obj_to_s(obj : LcVal)
      converted = false
      loop do
        if obj.is_a? Internal::LcString
          return obj
        elsif !converted
          obj = lc_call_fun(obj, "to_s")
          converted = true
        else
          return Internal.lc_obj_to_s(obj)
        end
      end
    end

    #######################################
    #  _____ _   _ ____   _____        __ #
    # |_   _| | | |  _ \ / _ \ \      / / #
    #   | | | |_| | |_) | | | \ \ /\ / /  #
    #   | | |  _  |  _ <| |_| |\ V  V /   #
    #   |_| |_| |_|_| \_\\___/  \_/\_/    #
    #######################################

    @[AlwaysInline]
    def vm_throw(state : UInt64, obj : LcVal)
      state = VM::ThrowState.new(state)
      case state
      when .raise?
        lc_raise(obj)
      when .break?, .next?
        ctype = state.break? ? CatchType::BREAK : CatchType::NEXT
        handler = vm_seek_exception_handler ctype
        if handler
          vm_handle_exception(handler, obj)
        else
          lc_bug("Invalid #{state.to_s.downcase} found")
        end
      when .return?
        save_current_frame
        current_env = @current_frame.env
        target_lenv = vm_env_lenv(current_env)
        i = @control_frames.size - 1
        while 0 <= i
          escape_frame = @control_frames[i]
          if escape_frame.env == target_lenv || escape_frame.flags.includes? VM::VmFrame::MAIN_FRAME
            break
          end
          i -= 1
        end
        unless escape_frame && escape_frame.flags.includes? VM::VmFrame.flags(UCALL_FRAME, PROC_FRAME)
          lc_raise(Internal.lc_localjmp_err, "Unexpected return")
        end
        # Silent return. It doesn't happen through vm_pop_control_frame
        @control_frames.delete_at(i, @control_frames.size - i)
        restore_regs
        push obj
      else
        lc_bug("Invalid or unhandled throw state (#{state})")
      end
    end

    @[AlwaysInline]
    private def vm_env_lenv(env : VM::Environment)
      while env && !env.frame_type.flag_local?
        env = env.previous
      end
      return env
    end

    protected def vm_seek_exception_handler(type : CatchType)
      save_current_frame
      while !@control_frames.empty?
        frame = @control_frames[-1]
        if frame.iseq?
          dist = frame.pc - frame.pc_bottom - 1 # pc is always 1 instruction ahead
          frame.iseq.catchtable.each do |ct_entry|
            if ct_entry.type == type && ct_entry.start <= dist <= ct_entry.end
              return ct_entry
            end
          end
        end
        @control_frames.pop
      end
      nil
    end

    protected def vm_handle_exception(ct_entry : CatchTableEntry, value : LcVal)
      debug "Handling exception"
      case ct_entry.type
      in .catch?
        restore_regs
        # In this case we want to wipe off the stack from any left values after the
        # passed call args.
        if @current_frame.flags.main_frame?
          @sp = 0
        else
          @sp = @control_frames[-2].real_sp
        end
        debug("State reset to [fc: #{@control_frames.size}][ss: #{@sp}]")
        debug("Handling frame: #{@current_frame.flags}")
        @pc = @current_frame.pc_bottom + ct_entry.cont
        env = vm_new_env(ct_entry.iseq, @current_frame.env.context, @current_frame.env, VM::VmFrame::CATCH_FRAME)
        env[0] = value.as(LcVal)
        set_stack_consistency_trace(0)
        vm_push_control_frame(
          me: @current_frame.me,
          iseq: ct_entry.iseq,
          env: env,
          flags: env.frame_type
        )
      in .break?
        if !@control_frames[-1].flags.block_frame?
          lc_raise(Internal.lc_localjmp_err, "Break from proc/captured block")
        end
        target_iseq = ct_entry.iseq
        while !@control_frames.empty? && @control_frames[-1].iseq? != target_iseq 
          @control_frames.pop
        end
        lc_bug("Failed to recover from break")  if @control_frames.empty?
        # now we are at the target frame
        restore_regs
        @pc = @current_frame.pc_bottom + ct_entry.cont
        push value # break is a sort of return
      in .next?
        # Next statement causes a throw only when used in blocks.
        # Therefore, the current frame is a block/proc frame. We just
        # need to set pc to the proper instruction
        restore_regs
        @pc = @current_frame.pc_bottom + ct_entry.cont
        push value
      end
      debug "Jumping to VM#exec"
      raise VM::LongJump.new # go back to VM#exec
    end

    protected def vm_raise_exception(error : Internal::LcError)
      unless ct_entry = vm_seek_exception_handler(CatchType::CATCH)
        debug("Raising exception and exit")
        vm_print_error error
        exit 1
      end
      vm_handle_exception(ct_entry, error)
    end

    @[AlwaysInline]
    private def vm_print_error(error : Internal::LcError)
      puts "Traceback (most recent call last)", 
            error.backtrace, 
            error.body
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
      method_entry = method.method
      ci = CallInfo.new(
        name: method_entry.name,
        argc: argv.size.to_i32,
        splat: false,
        dbl_splat: @current_frame.flags.includes?(VM::VmFrame::FLAG_KEYWORDS),
        kwarg: nil
      )
      calling = VM::CallingInfo.new(
        me: method.receiver, 
        argc: ci.argc, 
        block: vm_get_block
      )
      push method.receiver
      argv.each { |arg| push arg }
      return call_method_with_handled_return(method_entry, ci, calling)
    end

    @[AlwaysInline]
    protected def call_method_with_handled_return(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo)
      vm_call_any(method, ci, calling, VM::VmFrame::FLAG_FINISH)
      case method.flags
      when .internal?, .python?, .attr_reader?, .attr_writer?
        return pop
      when .user?, .proc?
        return exec
      else
        lc_bug("Missing implementation for calling #{method.flags}")
      end
      Null # unreachable
    end

    def lc_call_fun(receiver :  LcVal, method : String, *argv)
      ci = CallInfo.new(
        name: method,
        argc: argv.size.to_i32,
        splat: false,
        dbl_splat: false,
        kwarg: nil
      )
      calling = VM::CallingInfo.new(
        me: receiver, 
        argc: ci.argc, 
        block: nil
      )
      push receiver
      argv.each { |arg| push arg }
      type = vm_call(ci, calling, VM::VmFrame::FLAG_FINISH)
      case type
      when .user?, .proc?
        return exec
      else
        return pop
      end
    end

    def lc_yield(*argv :  LcVal)
      argv.each { |arg| push arg }
      ci = CallInfo.new(
        name: "",
        argc: argv.size.to_i32,
        splat: false,
        dbl_splat: false,
        kwarg: nil
      )
      calling = VM::CallingInfo.new(
        me: @current_frame.me, 
        argc: ci.argc, 
        block: nil
      )
      vm_invoke_block(ci, calling, VM::VmFrame::FLAG_FINISH)
      return exec
    end

    @[AlwaysInline]
    def lc_raise(type, msg)
      error = Internal.build_error(
        type,
        msg,
        vm_get_backtrace
      )
      lc_raise(error)
    end

    @[AlwaysInline]
    def lc_raise_syntax_error(msg, last_loc)
      error = Internal.build_error(
        Internal.lc_syntax_err,
        msg,
        vm_get_backtrace + last_loc
      )
      lc_raise(error)
    end

    def lc_raise(error :  LcVal)
      error = error.as(Internal::LcError)
      if error.backtrace.empty?
        error.backtrace = vm_get_backtrace
      end
      vm_raise_exception(error)
      error # Unreachable. For inference purposes only
    end 

    @[AlwaysInline]
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

    def get_current_filedir
      @control_frames.reverse_each do |frame|
        if !(frame.flags.includes? VM::VmFrame.flags(ICALL_FRAME, PCALL_FRAME, DUMMY_FRAME))
          return File.dirname(frame.iseq.filename)
        end
      end
      "" # unreachable
    end

    def run(iseq : ISeq)
      obj = @control_frames.first.me
      set_stack_consistency_trace 0
      vm_push_control_frame(obj, Internal.lc_object, iseq, VM::VmFrame.flags(TOP_FRAME, FLAG_FINISH, FLAG_LOCAL))
      return exec
    end

    def error?
      lc_bug("Deprecated error handling used")
      false 
    end
    
  end 
end