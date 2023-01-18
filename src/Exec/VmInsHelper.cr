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

    protected def vm_call(ci : CallInfo, calling : CallingInfo)
    end 

    protected def vm_call_no_block(ci : CallInfo, calling : CallingInfo)
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