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
  class VM
    include Internal
    include VmInsHelper
    include Backtrace 

    class LongJump < Exception; end

    alias BlockHandler = LcBlock | LCProc
    alias Context = LcClass | LcMethod

    macro convert(err)
      LinCAS.convert_error({{err}})
    end

    macro get_is_and_operand(ins)
      { {{ins}} & IS::IS_MASK, ({{ins}} & IS::OP_MASK).value }
    end 

    macro debug(msg)
      {% if flag?(:vm_debug) %}
        puts {{msg}}
      {% end %}
    end 

    macro topn(x)
      @stack[@sp - ({{x}}) - 1]
    end

    def initialize
      @control_frames = [] of ExecFrame
      @stack          = uninitialized Ary
      @current_frame  = uninitialized ExecFrame
      @pc             = Pointer(IS).null
      @sp = 0
      @initialized = false
    end

    def init
      @stack = Ary[]
      @initialized = true
    end

    def setup_iseq(iseq : ISeq)
      if !@initialized
        lc_bug("Uninitialized VM")
      end
      obj = Internal.boot_main_object
      vm_push_control_frame(obj, Internal.lc_object, iseq, VmFrame.flags(MAIN_FRAME, FLAG_FINISH, FLAG_LOCAL))
      @pc = @current_frame.pc
    end

    # This routine is used when popping control frames
    @[AlwaysInline]
    protected def restore_regs
      if @control_frames.empty?
        lc_bug("(No frame found)")
      end
      restore_cfp_and_pc
      debug "Restoring sp at #{@current_frame.sp} [current: #{@sp}]"
      @sp = @current_frame.sp
    end

    # This routine is used when pushing control frames
    # or popping them. It doesn't restore the stack pointer
    # (It is not necessary when pushing a new cf)
    @[AlwaysInline]
    protected def restore_cfp_and_pc
      @current_frame = @control_frames.last
      @pc = @current_frame.pc
    end

    @[AlwaysInline]
    protected def vm_new_frame(me, iseq, env, flags)
      ExecFrame.new(me, iseq, env, flags)
    end

    @[AlwaysInline]
    protected def vm_new_frame(me, env, flags)
      ExecFrame.new(me, env, flags)
    end

    @[AlwaysInline]
    protected def save_current_frame
      @control_frames[-1] = @current_frame.copy_with pc: @pc unless @control_frames.empty?
    end

    @[AlwaysInline]
    protected def push_control_frame(frame)
      # We need to save the current frame updating it with the current pc
      save_current_frame

      # now we can push the new frame
      @control_frames << frame
      restore_cfp_and_pc
      debug("Pushing cf #{@current_frame.flags} [fc: #{@control_frames.size}] [ss: #{@sp}]")
    end

    @[AlwaysInline]
    protected def vm_push_control_frame(me : LcVal, iseq : ISeq, env : Environment, flags)
      frame = vm_new_frame(me, iseq, env, flags)
      push_control_frame frame
    end

    @[AlwaysInline]
    protected def vm_push_control_frame(me : LcVal, context : Context, iseq : ISeq, flags)
      env = Environment.new(iseq.symtab.size, context, flags)
      vm_push_control_frame(me, iseq, env, flags)
    end

    ##
    # Used for calls to internal methods only
    @[AlwaysInline]
    protected def vm_push_control_frame(me : LcVal, context : Context, block : BlockHandler?, flags)
      env = Environment.new(0, context, flags, block)
      frame = vm_new_frame(me, env, flags)
      push_control_frame frame
    end

    protected def vm_pop_control_frame
      debug("Popping cf: #{@current_frame.flags} [fc: #{@control_frames.size}] [ss: #{@sp}]")
      r_value = pop
      flags = @current_frame.flags 
      @control_frames.pop 
      vm_consistency_check
      unless flags.includes? VmFrame::MAIN_FRAME
        restore_regs
        debug("Current frame: #{@current_frame.flags}. [fc: #{@control_frames.size}] [ss: #{@sp}]")
      end
      push r_value
      return flags.includes? VmFrame::FLAG_FINISH
    end

     @[AlwaysInline]
    protected def push(object :  LcVal)
      if @sp >= @stack.size
        @stack.push(object)
      else 
        @stack[@sp] = object 
      end  
      @sp += 1
      debug("Push on stack [ss: #{@sp}]")
    end

    @[AlwaysInline]
    protected def pop 
      if @sp < 0
        lc_bug("VM ran in stack underflow")
      end 
      @sp -= 1
      debug("Pop from stack [ss: #{@sp}]")
      return @stack[@sp]
    end 

    @[AlwaysInline]
    def next_is
      vm_pc_consistency_check
      value = @pc.value 
      @pc += 1
      return value
    end
    
    def exec : LcVal
      cfp = @control_frames.size
      # this loop rescues a long jump after exception handling
      # and allows the VM to start over from the new instructions
      while true
        begin
          # This is the real VM loop
          while true
            ins = next_is
            is, op = get_is_and_operand(ins)
            debug("executing instruction #{is}:#{op}")
            case is 
            when .noop?
              # nothing to do
            when .setlocal?
              offset = next_is.value
              vm_setlocal(offset, op, topn(0))
            when .setlocal_0?
              vm_setlocal_0(op, topn(0))
            when .setlocal_1?
              vm_setlocal_1(op, topn(0))
            when .setlocal_2?
              vm_setlocal_2(op, topn(0))
            when .getlocal?
              offset = next_is.value
              value = vm_getlocal(offset, op)
              push(value)
            when .getlocal_0?
              value = vm_getlocal_0(op)
              push(value)
            when .getlocal_1?
              value = vm_getlocal_1(op)
              push(value)
            when .getlocal_2?
              value = vm_getlocal_2(op)
              push(value)
            when .setinstance_v?
              name = @current_frame.names[op]
              value = pop 
              vm_setinstance_v(name, @current_frame.me, value)
              push(value)
            when .getinstance_v?
              name = @current_frame.names[op]
              value = vm_getinstance_v(name, @current_frame.me)
              push(value)
            when .setclass_v?
              name  = @current_frame.names[op]
              value = pop 
              vm_setclass_v(name, @current_frame.me, value)
              push(value)
            when .getclass_v?
              name = @current_frame.names[op]
              value = vm_getclass_v(name, @current_frame.me)
              push(value)
            when .storeconst?
              name  = @current_frame.names[op]
              value = pop 
              me    = pop
              vm_storeconst(name, me, value)
              push(value)
            when .getconst?
              name  = @current_frame.names[op]
              allow_null = pop
              push(vm_getconst(pop, name, allow_null == LcTrue))
            when .pop?
              pop
            when .pushobj?
              push(@current_frame.objects[op])
            when .push_true?
              push(LcTrue)
            when .push_false?
              push(LcFalse)
            when .push_self?
              push(@current_frame.me)
            when .push_null?
              push(Null)
            when .dup?
              push topn(0)
            when .call?
              ci = @current_frame.call_info[op]
              bh = vm_capture_block(ci)
              with_calling_info(me: topn(ci.argc), argc: ci.argc, block: bh) do |calling|
                vm_call(ci, calling)
              end
            when .call_no_block?
              ci           = @current_frame.call_info[op]
              with_calling_info(me: topn(ci.argc), argc: ci.argc, block: nil) do |calling|
                vm_call(ci, calling)
              end
            when .invoke_block?
              ci = @current_frame.call_info[op]
              with_calling_info(
                me: @current_frame.me, 
                argc: ci.argc, 
                block: nil # Should not be used
              ) do |calling|
                vm_invoke_block(ci, calling)
              end
            when .const_or_call?, .call_or_const?
              ci = @current_frame.call_info[op]
              with_calling_info(
                me: @current_frame.me, 
                argc: ci.argc, 
                block: nil # Should not be used
              ) do |calling|
                vm_call_or_const(ci, calling, is)
              end
            when .put_class?
              parent = pop 
              me     = pop
              name   = @current_frame.names[op]
              op2     = next_is
              iseq   = @current_frame.iseq.jump_iseq[op2.value]
              vm_putclass(me, name, parent, iseq)
            when .put_module?
              me   = pop
              name = @current_frame.names[op]
              op2  = next_is
              iseq = @current_frame.iseq.jump_iseq[op2.value]
              vm_putmodule(me, name, iseq)
            when .define_method?
              oo = next_is
              index, jmp_iseq = get_is_and_operand oo
              index = index.value >> 32
              name = @current_frame.names[index]
              iseq = iseq = @current_frame.iseq.jump_iseq[jmp_iseq]
              vm_define_method(op.to_i32, nil, name, iseq, false)
            when .define_smethod?
              receiver = pop
              oo = next_is
              index, jmp_iseq = get_is_and_operand oo
              index = index.value >> 32
              name = @current_frame.names[index]
              iseq = iseq = @current_frame.iseq.jump_iseq[jmp_iseq]
              vm_define_method(op.to_i32, receiver, name, iseq, true)
            when .jumpt?
              vm_jumpt(pop, op)
            when .jumpf?
              vm_jumpf(pop, op)
            when .jump?
              vm_jump(op)
            when .jumpf_and_pop?
              vm_jumpf_and_pop(pop, op)
            when .check_kw?
              value = vm_check_kw(op)
              push(value)
            when .check_match?
              b = pop
              a = pop
              push vm_check_match(op, a, b)
            when .splat_array?
              ary = pop
              obj = vm_splat_array(ary)
              push(obj)
            when .concat_array?
              a2 = pop
              a1 = topn(0)
              vm_ary_concat(a1, a2)
            when .array_append?
              value = pop
              vm_array_append(topn(0), value)
            when .merge_kw?
              hash2 = pop 
              hash1 = topn(0)
              vm_merge_kw(hash1, hash2)
            when .dup_hash?
              hash = vm_dup_hash pop
              push hash
            when .str_concat?
              push vm_str_concat op
            when .make_range?
              v2 = pop
              v1 = pop
              push vm_make_range v1, v2, op
            when .new_hash?
              push vm_new_hash(op)
            when .new_array?
              push vm_new_array(op)
            when .new_object_with_block?
              ci = @current_frame.call_info[op]
              bh = vm_capture_block(ci)
              with_calling_info(
                me: Null, # set during the execution
                argc: ci.argc, 
                block: bh
              ) do |calling|
                vm_new_object(ci, calling)
              end
            when .new_object?
              ci = @current_frame.call_info[op]
              with_calling_info(
                me: Null, # set during the execution
                argc: ci.argc, 
                block: nil
              ) do |calling|
                vm_new_object(ci, calling)
              end
            when .obj2_string?
              push vm_obj_to_s pop
            when .throw?
              vm_throw(op, pop)
            when .leave?
              if vm_pop_control_frame
                return pop
              end
            else
              lc_bug("Invalid instruction received (#{is})")
            end
          end
        rescue LongJump
          unless cfp <= @control_frames.size
            # this is not the call that should handle the exception
            raise LongJump.new
          end
          # retry
        end
      end 
      # Unreachable
      lc_bug("VM ran out of loop")
    end

    # We want to make sure the calling info are not corrupted
    # by another function or block call before the original call has
    # finished (very important for new object instantiation).
    # Therefore, we separate the scope in the following method, so
    # we make sure calling_info is unique for each execution.
    #
    # Here there is also a small optimization in terms of memory.
    # We expect calls and block invoking to be quite frequent,
    # therefore it is quite inefficient to allocate CallingInfo objects
    # every time, and a struct doesn't fit as we may need to modify some
    # member of cCallingInfo.
    # So we can collect some stack memory through a static array, and cast
    # its pointer to CallingInfo. This solution can be unsafe
    @[AlwaysInline]
    def with_calling_info(**args)
      dont_touch_me = uninitialized UInt8[instance_sizeof(CallingInfo)]
      calling_info = dont_touch_me.to_unsafe.as(CallingInfo)
      calling_info.unsafe_init(**args)
      yield calling_info
    end

    @[AlwaysInline]
    def vm_get_block
      env = @current_frame.env
      while env && env.frame_type.includes? VmFrame::BLOCK_FRAME
        env = env.previous 
      end
      return env ? env.block_handler : nil
    end

    @[AlwaysInline]
    def block_given?
      return !!vm_get_block 
    end
    
    @[AlwaysInline]
    def get_class_ref
      context = @current_frame.env.context
      return context.is_a?(LcClass) ? context : context.owner
    end

    @[Flags]
    enum VmFrame : UInt32
      FLAG_NONE = 0
      FLAG_FINISH 
      FLAG_LOCAL 
      FLAG_KEYWORDS
       
      MAIN_FRAME  
      CLASS_FRAME 
      BLOCK_FRAME 
      PROC_FRAME  
      ICALL_FRAME
      PCALL_FRAME
      UCALL_FRAME
      DUMMY_FRAME
      CATCH_FRAME 
    end

    enum ThrowState : UInt64
      RAISE = 0
      BREAK = 1
      NEXT  = 2
      RETURN = 3
    end

    private struct ExecFrame
      getter me, env, flags, pc_bottom
      property sp, pc, real_sp
      getter! names, objects, call_info, iseq

      @pc        : IS*
      @pc_top    : IS*
      @names     : Array(String)?
      @objects   : Array(LcVal)?
      @call_info : Array(CallInfo)?

      def initialize(@me : LcVal, @iseq : ISeq, @env : Environment, @flags : VmFrame)
        # Program counter.
        @pc        = iseq.encoded.to_unsafe
        # Pc boundaries for consistency check
        @pc_bottom = @pc
        @pc_top    = @pc + iseq.encoded.size
        # Saves the stack size before the call args
        @sp        = 0
        # Saves the actual stack pointer. 
        # This is for consistency check
        @real_sp   = 0
        @names     = iseq.names
        @objects   = iseq.object
        @call_info = iseq.call_info
      end

      ##
      # This initializer is used only on calls
      # with internal method reference 
      def initialize(@me : LcVal, @env : Environment, @flags : VmFrame)
        @iseq = nil.as ISeq?
        @pc = @pc_bottom = @pc_top = Pointer(IS).null
        @sp = @real_sp = 0
        @names     = nil.as Array(String)?
        @objects   = nil.as Array(LcVal)?
        @call_info = nil.as Array(CallInfo)?
      end

      def copy_with(pc _pc = @pc, sp _sp = @sp, real_sp _real_sp = @real_sp)
        copy = self.dup
        copy.pc = _pc
        copy.sp = _sp
        copy.real_sp = _real_sp
        return copy
      end

      def consistent_pc?(pc)
        return @pc_bottom <= pc <= @pc_top
      end
    end

    class Environment < Array(LcVal)

      @block_handler : BlockHandler?
      def initialize(size, @context : Context, @frame_type : VmFrame, @previous : Environment? = nil)
        super(size, Null)
        @block_handler = nil
        @kw_bit = 0u64 # used in kw args
      end

      def initialize(size, @context : Context, @frame_type : VmFrame, @block_handler : BlockHandler?, @previous : Environment? = nil)
        super(size, Null)
        @kw_bit = 0u64 # used in kw args
      end

      getter previous, frame_type, context
      property block_handler, kw_bit

      def_equals object_id
    end

    class CallingInfo
      # me: self
      # argc: number of args on stack
      # block: block handler
      def initialize(@me : LcVal, @argc : Int32, @block : BlockHandler? = nil)
      end

      def unsafe_init(@me : LcVal, @argc : Int32, @block : BlockHandler? = nil)
        self
      end

      getter block
      property argc, me
    end

    ##
    # if @method is nil, @m_missing_status:
    #  * 0: undefined
    #  * 1: protected method called (explicit call)
    #  * 2: private method called
    struct CallCache
      def initialize(
        @method : LcMethod?,
        @m_missing_status : Int32,
        @orig_serial : Serial
      )
        @klass = nil.as(LcClass?)
      end

      getter method, m_missing_status, orig_serial
      property! klass

      def_equals method, orig_serial, klass
    end


  end
  
  Exec = VM.new
end