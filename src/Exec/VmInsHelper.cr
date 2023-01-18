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

    macro set_stack_consistency_trace(offset)
      @current_frame.sp = @sp - {{offset}}
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
      if !@current_frame.consistent_pc?
        lc_bug("Inconsistent program counter detected")
      end
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

    protected def vm_setinstance_v(name : String, me : LcVal, value : LcVal)
    end

    protected def vm_getinstance_v(name : String, me : LcVal)
    end

    protected def vm_setclass_v(name : String, me : LcVal, value : LcVal)
    end

    protected def vm_getclass_v(name : String, me : LcVal)
    end

    protected def vm_storeconst(name : String, me : LcVal, value : LcVal)
    end

    protected def vm_getconst(name : String, me : LcVal)
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
      cc = Internal.seek_method(calling.me.klass, ci.name, ci.explicit)
      vm_no_method_found(ci, calling, cc) if cc.method.nil?
      method = cc.method.not_nil!
      
      # We already have the arguments on the stack that
      # are already available. Local variables are not 
      # kept on stack, therefore it will be the specialized
      # call-handler function's responsability to copy them
      # to the environment context.
      #
      # Since we need to clear the arg part after the call.
      # Therefore we need to remember what is the actual stack
      # pointer before the call args (and before pushing a new frame)
      set_stack_consistency_trace(ci.argc) # TO FIX: consider Kw args

      return case method.type 
      when .internal?
        vm_call_internal(method, ci, calling) # Missing: fixing args on stack
      # when .user?
      # when .python?
      # when .proc?
      else
        lc_bug("Invalid method type received")
        Null
      end
    end 

    private def vm_call_internal(method : LcMethod, ci : CallInfo, calling : VM::CallingInfo)
      vm_push_control_frame(calling.me, VM::VmFrame::ICALL_FRAME)
      vm_check_arity(method.arity, ci.argc) if method.arity > 0
      argv = vm_collect_args(method.arity, ci)
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

    private def vm_call_user()
    end 

    private def vm_call_python()
    end

    protected def vm_putclass(me : LcVal, name : String, parent : LcVal, iseq : ISeq)
    end 

    protected def vm_putmodule(me : LcVal, name : String, iseq : ISeq)
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
    end

    def lc_raise(error :  LcVal)
    end 

    def get_block 
      vm_get_block
    end
    
  end 
end