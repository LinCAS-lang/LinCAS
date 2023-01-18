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
    end

    @[AlwaysInline]
    protected def restore_regs
      if @control_frames.empty?
        lc_bug("(No frame found)")
      end
      @current_frame = @control_frames.last
      @sp = @current_frame.sp
    end

    @[AlwaysInline]
    protected def vm_new_frame(me, iseq, env, flags)
      ExecFrame.new(me, iseq, env, flags)
    end

    protected def vm_push_control_frame(me, iseq, env, flags)
      frame = vm_new_frame(me, iseq, env, flags)
      @control_frames << frame
      @current_frame = @control_frames.last
      debug("Pushing cf #{@current_frame.flags}. [fc: #{@control_frames.size}]")
    end

    protected def vm_push_control_frame(me, iseq, flags)
      env = Environment.new(iseq.symtab.size, flags)
      vm_push_control_frame(me, iseq, env, flags)
    end

    protected def vm_push_control_frame(me, flags)
      env = Environment.new(0, flags)
      iseq = uninitialized ISeq # Unsafe code
      vm_push_control_frame(me, iseq, env, flags)
    end

    protected def vm_pop_control_frame
      debug("Popping cf: #{@current_frame.flags}. [fc: #{@control_frames.size}]")
      r_value = pop
      flags = @current_frame.flags 
      @control_frames.pop 
      vm_consistency_check
      unless flags.includes? VmFrame::MAIN_FRAME
        restore_regs
        debug("Current frame: #{@current_frame.flags}. [fc: #{@control_frames.size}]")
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
    end

    @[AlwaysInline]
    protected def pop 
      if @sp < 0
        # lc_bug"(VM ran in stack underflow)"
      end 
      @sp -= 1
      return @stack[@sp]
    end 
    
    def exec
      LibC.setjmp(@current_frame.buff)
      while !(ins = @current_frame.pc.next).is_a?(Iterator::Stop)
        is, op = get_is_and_operand(ins)
        debug("executing instruction #{is}:#{op}")
        case is 
        when .noop?
        when .setlocal?
          offset = @current_frame.pc.next.value
          vm_setlocal(offset, op, topn(0))
        when .setlocal_0?
          vm_setlocal_0(op, topn(0))
        when .setlocal_1?
          vm_setlocal_1(op, topn(0))
        when .setlocal_2?
          vm_setlocal_2(op, topn(0))
        when .getlocal?
          offset = @current_frame.pc.next.value
          vm_getlocal(offset, op)
        when .getlocal_0?
          vm_getlocal_0(op)
        when .getlocal_1?
          vm_getlocal_1(op)
        when .getlocal_2?
          vm_getlocal_2(op)
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
          push(value)
        when .storeconst?
          name  = @current_frame.names[op]
          value = pop 
          me    = pop
          vm_storeconst(name, me, value)
          push(value)
        when .getconst?
          name  = @current_frame.names[op]
          me    = pop
          vm_getreconst(name, me)
          push(value)
        when .pop
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
          ci           = @current_frame.call_info[op]
          bh           = vm_capture_block(ci)
          calling_info = CallingInfo.new(topn(ci.argc), bh)
          vm_call(ci, calling_info)
        when .call_no_block?
          ci           = @current_frame.call_info[op]
          calling_info = CallingInfo.new(topn(ci.argc), nil)
          vm_call_no_block(ci, calling_info)
        when .putclass?
          parent = pop 
          me     = pop
          name   = @current_frame.names[op]
          p2     = @current_frame.pc.next
          iseq   = @current_frame.iseq.jump_iseq[op2.value]
          vm_putclass(me, name, parent, iseq)
        when .putmodule?
          me   = pop
          name = @current_frame.names[op]
          op2  = @current_frame.pc.next
          iseq = @current_frame.iseq.jump_iseq[op2.value]
          vm_putmodule(me, name, iseq)
        when .jumpt?
        when .jumpf?
        when .jump?
        when .jumpf_and_pop?
        when .make_range?
        when .leave?
          if vm_pop_control_frame
            return topn(0)
          else 
            value = topn(0)
            restore_regs
            push(value)
          end
        else
          # lc_bug("Invalid instruction received (#{is})")
        end
      end 
      # Unreachable
      # lc_bug("VM ran out of loop")
    end

    @[AlwaysInline]
    def vm_get_block
      return @current_frame.env.block_handler # To adjust for nested blocks (Yeld?)
    end

    private enum VmFrame : UInt32
      MAIN_FRAME  = 1 << 6
      CLASS_FRAME = 2 << 6
      BLOCK_FRAME = 3 << 6
      PROC_FRAME  = 4 << 6
      CALL_FRAME  = 5 << 6

      FLAG_FINISH = 1
    end

    private class ExecFrame
      getter me, iseq, env, flags, pc, local_var, names, objects, call_info, jump_buff
      property sp
      def initialize(@me : LcVal, @iseq : ISeq, @env : Environment, @flags : VmFrame)
        @pc        = iseq.encoded.each
        @sp        = 0
        @local_var = Array(LcVal).new(iseq.symtab.size)
        @names     = iseq.names
        @objects   = iseq.object
        @call_info = iseq.call_info
        @jump_buff = StaticArray[LibC::JmpBuf.new]
      end
    end

    class Environment < Array(LcVal)
      @prevuous : Environment?
      @block_handler : BlockHandler? 
      def initialize(size, @prevuous = nil)
        super(size)
        @block_handler = nil
      end

      getter prevuous
      setter block_handler
    end

    protected record CallingInfo, 
      me : LcVal,
      block : BlockHandler?


  end
  
  Exec = VM.new
end