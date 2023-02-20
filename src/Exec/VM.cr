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

    alias BlockHandler = LcBlock | LCProc
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
      vm_push_control_frame(obj, iseq, VmFrame::MAIN_FRAME | VmFrame::FLAG_FINISH)
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
    protected def push_control_frame(frame)
      # We need to save the current frame updating it with the current pc
      @control_frames[-1] = @current_frame.copy_with pc: @pc unless @control_frames.empty?

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
    protected def vm_push_control_frame(me : LcVal, iseq : ISeq, flags)
      env = Environment.new(iseq.symtab.size, flags)
      vm_push_control_frame(me, iseq, env, flags)
    end

    ##
    # Used for calls to internal methods only
    @[AlwaysInline]
    protected def vm_push_control_frame(me : LcVal, block : BlockHandler?, flags)
      env = Environment.new(0, flags, block)
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
    
    def exec
      #LibC.setjmp(@current_frame.jump_buff.to_unsafe)
      dont_touch_me = uninitialized UInt8[instance_sizeof(CallingInfo)]
      calling_info = dont_touch_me.to_unsafe.as(CallingInfo)
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
          me    = pop
          vm_setinstance_v(name, me, value)
          push(value)
        when .getinstance_v?
          name = @current_frame.names[op]
          me   = pop
          value = vm_getinstance_v(name, me)
          push(value)
        when .setclass_v?
          name  = @current_frame.names[op]
          value = pop 
          me    = pop
          vm_setclass_v(name, me, value)
          push(value)
        when .getclass_v?
          name = @current_frame.names[op]
          me   = pop
          value = vm_getinstance_v(name, me)
          # push(value)
        when .storeconst?
          name  = @current_frame.names[op]
          value = pop 
          me    = pop
          vm_storeconst(name, me, value)
          push(value)
        when .getconst?
          name  = @current_frame.names[op]
          me    = pop
          vm_getconst(name, me)
          # push(value)
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
        when .call?
          ci            = @current_frame.call_info[op]
          bh            = vm_capture_block(ci)
          calling_info.unsafe_init(
            topn(ci.argc), 
            ci.argc, 
            bh
          )
          vm_call(ci, calling_info)
        when .call_no_block?
          ci           = @current_frame.call_info[op]
          calling_info.unsafe_init(
            topn(ci.argc), 
            ci.argc, 
            nil
          )
          vm_call(ci, calling_info)
        when .invoke_block?
          ci = @current_frame.call_info[op]
          calling_info.unsafe_init(
            me: @current_frame.me, 
            argc: ci.argc, 
            block: nil # Should not be used
          )
          vm_invoke_block(ci, calling_info)
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
        when .make_range?
          v2 = pop
          v1 = pop
          push vm_make_range v1, v2, op
        when .new_hash?
          vm_new_hash(op)
        when .leave?
          if vm_pop_control_frame
            return pop
          end
        else
          lc_bug("Invalid instruction received (#{is})")
        end
      end 
      # Unreachable
      lc_bug("VM ran out of loop")
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

    enum VmFrame : UInt32
      MAIN_FRAME  = 1 << 6
      CLASS_FRAME = 1 << 7
      BLOCK_FRAME = 1 << 8
      PROC_FRAME  = 1 << 9
      ICALL_FRAME = 1 << 10
      PCALL_FRAME = 1 << 11
      UCALL_FRAME = 1 << 12

      FLAG_FINISH = 1
    end

    private struct ExecFrame
      getter me, env, flags, jump_buff, pc_bottom
      property sp, pc, real_sp
      getter! names, objects, call_info, iseq

      @pc        : IS*
      @pc_top    : IS*
      @names     : Array(String)?
      @objects   : Array(LcVal)?
      @call_info : Array(CallInfo)?
      @jump_buff : StaticArray(LibC::JmpBuf, 1)

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
        @jump_buff = StaticArray[LibC::JmpBuf.new]
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
        @jump_buff = StaticArray[LibC::JmpBuf.new]
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
      def initialize(size, @frame_type : VmFrame, @previous : Environment? = nil)
        super(size, Null)
        @block_handler = nil
        @kw_bit = 0u64 # used in kw args
      end

      def initialize(size, @frame_type : VmFrame, @block_handler : BlockHandler?, @previous : Environment? = nil)
        super(size, Null)
        @kw_bit = 0u64 # used in kw args
      end

      getter previous, frame_type
      property block_handler, kw_bit
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

      getter me, block
      property argc
    end

    ##
    # if @method is nil, @m_missing_status:
    #  * 0: undefined
    #  * 1: protected method called (explicit call)
    #  * 2: private method called
    record CallCache,
      method : LcMethod?,
      m_missing_status : Int32


  end
  
  Exec = VM.new
end