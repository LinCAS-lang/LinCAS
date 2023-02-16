
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

    #$C Proc
        
    class LCProc < LcVal
        @init = false
        @me   = uninitialized  LcVal
        @iseq = uninitialized ISeq
        @env  = uninitialized VM::Environment
        @part = [] of  LcVal
        property init, me, args, iseq, env
        getter part
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

    macro set_proc_code(proc,code)
        {{proc}}.as(LCProc).iseq = {{code}}
    end

    macro get_proc_code(proc)
        {{proc}}.as(LCProc).iseq
    end

    macro set_proc_scope(proc,scp)
        {{proc}}.as(LCProc).env = {{scp}}
    end

    macro get_proc_scope(proc)
        {{proc}}.as(LCProc).env
    end

    macro set_proc_as_init(proc)
        {{proc}}.as(LCProc).init = true
    end

    macro get_proc_part(proc)
        {{proc}}.as(LCProc).part
    end

    macro is_initialized_proc?(proc)
        ({{proc}}.as(LCProc).init)
    end

    macro check_proc(proc)
        if !({{proc}}.is_a? LCProc)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{proc}})} into Proc")
            return Null
        elsif !is_initialized_proc? {{proc}}
            # lc_raise(LcInstanceErr,"Proc uncorrectly initialized")
            return Null
        end
    end

    def self.lc_proc_allocate_0(klass :  LcVal)
        klass = klass.as(LcClass)
        proc  = lincas_obj_alloc LCProc, klass
        proc.id    = proc.object_id
        return proc.as( LcVal)
    end

    def self.lc_proc_allocate(klass :  LcVal)
        block = Exec.get_block
        proc = lc_proc_allocate_0(klass)
        if block
            if block.is_a? LCProc 
                return lc_cast(block, LcVal)
            else 
                proc_init(proc,lc_cast(block, LcBlock))
            end
        else
            lc_raise(LcArgumentError,"Tried to create a proc without a block")
        end
        return proc
    end

    def self.build_proc
        return lc_proc_allocate(@@lc_proc)
    end

    def self.lincas_block_to_proc(block : LcBlock)
        proc = build_proc 
        proc_init(proc,block)
        return proc
    end

    @[AlwaysInline]
    def self.lincas_block_to_proc(block : LCProc)
      return lc_cast(block, LcVal)
    end 

    private def self.proc_init(proc :  LcVal,block : LcBlock)
        set_proc_self(proc, block.me)
        set_proc_code(proc, block.iseq)
        set_proc_scope(proc,block.env)
        set_proc_as_init(proc)
    end

    def self.lc_proc_init(proc :  LcVal)
        block      = Exec.get_block
        if block.is_a? LcBlock 
            proc_init(proc,block)
        elsif block.is_a? LCProc 
            # Do nothing. It is the same object
        else
            lc_raise(LcArgumentError,"Tried to create a proc without a block")
        end
        return proc
    end

    #$I call
    #$U call(*args)
    # Calls the procedure passing the given arguments
    
    def self.lc_proc_call(proc :  LcVal,argv :  LcVal)
        check_proc(proc)
        argv = argv.as Ary
        Exec.call_proc(lc_cast(proc,LCProc),argv)
    end

    private def self.clone_part(a : An)
        tmp = [] of  LcVal 
        a.times do |v|
            tmp << v 
        end
        tmp
    end

    ##
    # TODO: Revamp 
    def self.lc_proc_partial(proc :  LcVal, argv : An)
        proc_arity = get_proc_args(proc).size
        if argv.size >= proc_arity
            return Exec.call_proc(lc_cast(proc,LCProc),argv)
        end
        return proc if argv.empty?
        part = get_proc_part(proc)
        diff = proc_arity - part 
        if diff <= argv.size 
            tmp = clone_part(part)
            diff.times do |i|
                tmp << argv[i]
            end
            return Exec.call_proc(lc_cast(proc,LCProc),tmp)
        else
            new_proc = lc_proc_clone(proc)
            part = get_proc_part(proc)
            argv.each do |v|
                part << v 
            end
            return new_proc
        end
    end

    def self.lc_proc_clone(proc :  LcVal)
        new_proc = build_proc
        set_proc_self(new_proc, get_proc_self(proc))
        set_proc_code(new_proc, get_proc_code(proc))
        set_proc_scope(new_proc,get_proc_scope(proc))
        p_part = get_proc_part(proc)
        n_part = get_proc_part(new_proc)
        if is_initialized_proc? proc
            p_part.each do |v|
                n_part << v
            end
            set_proc_as_init(new_proc)
        end
        return new_proc
    end

    def self.init_proc
        @@lc_proc = lc_build_internal_class("Proc")
        define_allocator(@@lc_proc,lc_proc_allocate_0)

        add_method(@@lc_proc, "init",lc_proc_init,   0)
        add_method(@@lc_proc, "call",lc_proc_call,  -1)
        add_method(@@lc_proc, "clone",lc_proc_clone, 0)
    end

end
