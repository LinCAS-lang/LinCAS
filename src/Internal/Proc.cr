
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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



module LinCAS::Internal
        
    class LCProc < BaseC
        @init = false
        @me   = uninitialized Value
        @args = uninitialized FuncArgSet
        @code = uninitialized Bytecode
        @scp  = uninitialized VM::Scope
        property init, me, args, code, scp
    end

    macro set_proc_self(proc,me)
        {{proc}}.as(LCProc).me = {{me}}
    end

    macro get_proc_self(proc)
        {{proc}}.as(LCProc).me
    end

    macro set_proc_args(proc,args)
        {{proc}}.as(LCProc).args = {{args}}
    end

    macro get_proc_args(proc)
        {{proc}}.as(LCProc).args
    end

    macro set_proc_code(proc,code)
        {{proc}}.as(LCProc).code = {{code}}
    end

    macro get_proc_code(proc,code)
        {{proc}}.as(LCProc).code
    end

    macro set_proc_scope(proc,scp)
        {{proc}}.as(LCProc).scp = {{scp}}
    end

    macro get_proc_scope(proc,scp)
        {{proc}}.as(LCProc).scp
    end

    macro set_proc_as_init(proc)
        {{proc}}.as(LCProc).init = true
    end

    macro check_proc(proc)
        if !({{proc}}.is_a? LCProc)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{proc}})} into Proc")
            return Null
        elsif !({{proc}}.as(LCProc).init)
            # lc_raise(LcInstanceErr,"Proc uncorrectly initialized")
            return Null
        end
    end

    def self.lc_proc_allocate_0(klass : Value)
        klass      = klass.as(LcClass)
        proc       = LCProc.new
        proc.klass = klass
        proc.data  = klass.data.clone
        proc.id    = proc.object_id
        return proc.as(Value)
    end

    def self.lc_proc_allocate(klass : Value)
        proc = lc_proc_allocate_0(klass)
        block      = Exec.get_block
        if block 
            proc_init(proc,block)
        else
            lc_raise(LcArgumentError,"Tried to create a proc without a block")
        end
        return proc
    end

    proc_allocator = LcProc.new do |args|
        next lc_proc_allocate_0(*lc_cast(args,T1))
    end

    def self.build_proc
        return lc_proc_allocate(ProcClass)
    end

    def self.lincas_block_to_proc(block : LcBlock)
        proc = build_proc 
        proc_init(proc,block)
        return proc
    end

    private def self.proc_init(proc : Value,block : LcBlock)
        set_proc_self(proc, block.me)
        set_proc_args(proc, block.args)
        set_proc_code(proc, block.body)
        set_proc_scope(proc,block.scp.as(VM::Scope))
        set_proc_as_init(proc)
    end

    def self.lc_proc_init(proc : Value)
        block      = Exec.get_block
        if block 
            proc_init(proc,block)
        else
            lc_raise(LcArgumentError,"Tried to create a proc without a block")
        end
        return proc
    end

    proc_init_ = LcProc.new do |args|
        next lc_proc_init(*lc_cast(args,T1))
    end

    def self.lc_proc_call(proc : Value,args : An)
        check_proc(proc)
        Exec.call_proc(lc_cast(proc,LCProc),args)
    end

    proc_call = LcProc.new do |args|
        args = lc_cast(args,An)
        next lc_proc_call(args.shift,args)
    end

    ProcClass = lc_build_internal_class("Proc")
    lc_set_allocator(ProcClass,proc_allocator)

    lc_add_internal(ProcClass, "init", proc_init_,        0)
    lc_add_internal(ProcClass, "call", proc_call,        -1)

end
