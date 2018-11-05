
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

require "./VMcall_tracker"

class LinCAS::VM < LinCAS::MsgGenerator

    MAX_STACK_DEPTH = 2000
    
    alias LcError  = Internal::LcError


    private struct ObjectWrapper
        def initialize(@object :  LcVal)
        end
        getter object
    end

    private class VMerror < Exception        
    end

    private class ErrorHandler
        @error :  LcVal? = nil 
        @ex_h  = 0
        getter error 

        @[AlwaysInline]
        def exception_handler?
            return @ex_h > 0
        end

        @[AlwaysInline]
        def exception_handler=(value : Int32)
            @ex_h += value
        end

        @[AlwaysInline]
        def handled_error?
            return !!@error 
        end

        @[AlwaysInline]
        def handle_error(error :  LcVal?)
            @error = error 
        end
    end

    private enum SCPType
       CLASS_SCP
       BLOCK_SCP
       PROC_SCP
       CALL_SCP
       MAIN_SCP 
    end

    class Scope < Hash(String, LcVal)

        def initialize(@type : SCPType)
            super()
        end

        @previous : Scope?   = nil
        @lcblock  : LcBlock? = nil 
        @ans      :  LcVal    = Null

        property previous, lcblock, ans
        getter type

        def set_var(name : String, object :  LcVal)
            self[name] = object 
        end 

        def get_var(name : String)
            self[name]?
        end

    end

    enum FrameType
        CLASS_FRAME
        BLOCK_FRAME
        PROC_FRAME
        CALL_FRAME
        MAIN_FRAME
    end

    private class LcFrame
        @fp      = 0                          # frame pointer
        @pc      = uninitialized Bytecode     # program count
        @scp     = uninitialized Scope        # scope pointer
        @catch_t : CatchTable? = nil
        @last_is : Bytecode?   = nil
        @handled_ret           = false
        
        def initialize(@me :  LcVal,@context : Structure,@argc : IntnumR,@type : FrameType)  
        end

        property fp,argc,pc,scp,me,context,catch_t,type,last_is, handled_ret

        @[AlwaysInline]
        def fetch 
            @pc.nextc
        end
    end

    private class FileInfo
        @line = 0.as(IntnumR)
        def initialize(@file : String)
        end
        property file,line
    end

    ErrHandler  = ErrorHandler.new 
    CallTracker = VMcall_tracker.new

    macro current_scope
        current_frame.scp
    end

    macro previous_scope_of(c_scope)
        {{c_scope}}.previous
    end

    macro internal 
        Internal 
    end

    macro call_internal(method,arg)
        {{method}}.call({{arg}}[0])
    end

    macro call_internal_1(method,arg)
        {{method}}.call({{arg}}[0],{{arg}}[1])
    end 

    macro call_internal_2(method,args)
        {{method}}.call({{args}}[0],{{args}}[1],{{args}}[2])
    end 

    macro call_internal_3(method,args)
        {{method}}.call({{args}}[0],{{args}}[1],{{args}}[2],{{args}}[3])
    end

    macro call_usr(method,argc)
        return nil unless vm_load_call_args({{method}}.args,{{argc}})
        current_frame.pc = {{method}}.code.as(Bytecode)
    end

    macro call_python(method,argv)
        internal.lc_call_python({{method}},{{argv}})
    end

    macro discard_arguments(argc)
        @sp -= {{argc}}
    end

    macro convert(err)
        LinCAS.convert_error({{err}})
    end

    macro get_context
        @framev[@vm_fp - 1].context
    end

    macro push_frame(frame)
        {% if flag?(:vm_debug) %}
            puts "pushing frame #{{{frame}}.type}".colorize(:red)
        {% end %}
        if @vm_fp == @framev.size 
            @framev.push({{frame}})
        else
            @framev[@vm_fp] = {{frame}}
        end 
        @vm_fp += 1
    end

    macro current_frame
        @framev[@vm_fp - 1]
    end

    macro filename 
        @location[@lp - 1].file 
    end

    macro line 
        @location[@lp - 1].line 
    end

    macro set_line(line)
        @location[@lp - 1].line = {{line}}
    end 

    macro test(value)
        internal.test({{value}})
    end 

    macro set_last_is(is)
        current_frame.last_is = {{is}}
    end

    macro pyobj_check(obj,name)
        if {{obj}}.is_a? Internal::LcPyObject
            method = internal.lc_seek_instance_pymethod({{obj}},{{name}})
            return method if method
        end
    end

    macro set_handle_ret_flag
        current_frame.handled_ret = true
    end

    @[AlwaysInline]
    private def class_of(obj :  LcVal)
        if obj.is_a? Structure 
            #if internal.struct_type(obj.as(Structure),SType::CLASS)
            #    return obj.klass 
            #end
            return obj 
        else 
            return obj.klass 
        end
    end

    @[AlwaysInline]
    def internal_call(method,args,arity)
        case arity
            when 0
                return call_internal(method,args)
            when 1
                return call_internal_1(method,args)
            when 2
                return call_internal_2(method,args)
            when 3
                return call_internal_3(method,args)
            else
                return call_internal_1(method,args)
        end
    end

    @to_replace : Bytecode?
    def initialize
        @stack   = Ary[]
        @framev  = [] of LcFrame
        @sp      = 0                          # stack pointer
        @vm_fp   = 0                          # frame pointer
        @lp      = 0                          # location pointer

        @location   = [] of FileInfo
        @msgHandler = MsgHandler.new
        @internal   = false
        @quit       = false
        @to_replace = nil
        @handle_ret = false

        self.addListener(RuntimeListener.new)
    end

    @[AlwaysInline]
    def messageHandler
        @msgHandler
    end

    protected def vm_print_stack
        puts @stack.shared_copy(0,@sp)
    end

    @[AlwaysInline]
    protected def ensured_stack_space?(count)
        if @sp + count > MAX_STACK_DEPTH
            lc_raise(LcSystemStackError,"(Stack level too deep)")
            return false 
        end 
        return true
    end

    @[AlwaysInline]
    protected def push(object :  LcVal)
        if ensured_stack_space? 1
            if @sp >= @stack.size
                @stack.push(object)
            else 
                @stack[@sp] = object 
            end  
            @sp += 1
        end
        # vm_print_stack
    end

    @[AlwaysInline]
    protected def pop 
        if @sp < 0
            raise VMerror.new("(VM ran in stack underflow)")
        end 
        @sp -= 1
        return @stack[@sp]
    end 

    @[AlwaysInline]
    protected def scope_type_for(type : FrameType)
        SCPType.new(type.value)
    end

    @[AlwaysInline]
    protected def new_frame(self_ref :  LcVal, context : Structure,argc : IntnumR,type : FrameType)
        if @vm_fp >= @framev.size
            return LcFrame.new(self_ref,context,argc,type)
        else 
            fm             = @framev[@vm_fp]
            fm.me          = self_ref
            fm.context     = context
            fm.argc        = argc
            fm.type        = type
            fm.handled_ret = false
            return fm 
        end
    end


    @[AlwaysInline]
    protected def vm_push_new_frame(self_ref :  LcVal, context : Structure,argc = 0,type = FrameType::CALL_FRAME )
        fm           = new_frame(self_ref,context,argc,type)
        fm.fp        = @sp 
        scp          = Scope.new(scope_type_for(type))
        scp.previous = current_scope
        fm.scp = scp
        push_frame(fm)
    end

    @[AlwaysInline]
    protected def vm_push_new_frame(self_ref :  LcVal, context : Structure,argc, scpr : Scope,type = FrameType::BLOCK_FRAME)
        fm           = new_frame(self_ref,context,argc,type)
        fm.fp        = @sp 
        scp          = Scope.new(scope_type_for(type))
        scp.previous = scpr
        fm.scp = scp
        push_frame(fm)
    end

    protected def push_shared_frame
        fm      = current_frame
        tmp     = new_frame(fm.me.as( LcVal),fm.context.as(Structure),fm.argc.as(Int32),fm.type)
        tmp.pc  = fm.pc 
        tmp.fp  = fm.fp
        tmp.scp = fm.scp
        push_frame(tmp)
    end

    @[AlwaysInline]
    protected def vm_pop_frame
        @vm_fp -= 1
        fm      = @framev[@vm_fp]
        @sp     = fm.fp
        {% if flag?(:vm_debug) %}
            puts "popping frame #{fm.type}".colorize(:red)
        {% end %}
        return fm.argc
    end

    @[AlwaysInline]
    protected def new_fileinfo(filename : String)
        loc = @location[@lp]?
        if loc 
            loc.file = filename
        else 
            loc = FileInfo.new(filename)
        end 
        return loc 
    end

    @[AlwaysInline]
    protected def vm_push_location(filename : String)
        loc = new_fileinfo(filename)
        if @lp == @location.size
            @location << loc
        else 
            @location[@lp] = loc
        end
        @lp += 1
    end

    macro vm_pop_location 
        @lp -= 1
    end

    @[AlwaysInline]
    def error?
        return ErrHandler.handled_error?
    end

    @[AlwaysInline]
    def fetch
        fm  = current_frame
        tmp = fm.fetch
        if tmp 
            fm.pc = tmp 
            return tmp
        else
            raise VMerror.new("VM failed to fetch bytecode (frame #{current_frame.type})")
        end 
    end

    @[AlwaysInline]
    def vm_set_ans(obj :  LcVal)
        current_frame.scp.ans = obj 
    end

    @[AlwaysInline]
    def run(bytecode : Bytecode)
        obj    = internal.boot_main_object
        fm     = new_frame(obj,class_of(obj),0,FrameType::MAIN_FRAME)
        fm.pc  = bytecode
        scp    = Scope.new(SCPType::MAIN_SCP)
        fm.scp = scp
        push_frame(fm)
        vm_run_bytecode
    end

    protected def vm_run_bytecode
        is = current_frame.pc
        loop do
            {% if flag?(:vm_debug) %}
                puts "Executing code #{is.code}"
            {% end %}
            case is.code
                when Code::LINE
                    set_line(is.line)
                when Code::FILENAME
                    vm_push_location(is.text)
                when Code::HALT
                    lincas_exit 0
                when Code::QUIT
                    return Null 
                when Code::PUSHN
                    push(Null)
                when Code::PUSHT
                    push(LcTrue)
                when Code::PUSHF
                    push(LcFalse)
                when Code::PUSHSELF
                    push(current_frame.me)
                when Code::PUSHINT
                    int = internal.num2int(is.value.as(Intnum))
                    push(int)
                when Code::PUSHFLO
                    flo = internal.num2float(is.value.as(Floatnum))
                    push(flo)
                when Code::PUSHSTR
                    str = internal.build_string(is.text)
                    push(str)
                when Code::POPOBJ
                    obj = pop
                    context = current_frame.scp 
                    context.ans = obj
                when Code::CALL
                    vm_call(is.text,is.argc)
                when Code::M_CALL
                    vm_m_call(is.text,is.argc)
                when Code::CALL_WITH_BLOCK
                    vm_call_with_block(is.text,is.argc,is.block.as(LcBlock))
                when Code::M_CALL_WITH_BLOCK
                    vm_m_call_with_block(is.text,is.argc,is.block.as(LcBlock))
                when Code::RETURN
                    vm_return
                    if @handle_ret
                        {% if flag?(:vm_debug) %}
                            puts "Handling return"
                        {% end %}
                        @handle_ret = false
                        return pop
                    end
                when Code::NEXT
                    vm_next
                    if @handle_ret
                        {% if flag?(:vm_debug) %}
                            puts "Handling next"
                        {% end %}
                        @handle_ret = false
                        return pop
                    end
                when Code::STOREL
                    vm_store_local(is.text,is.value.as(Intnum))
                when Code::STOREL_0
                    vm_store_local_0(is.text)
                when Code::STOREL_1
                    vm_store_local_1(is.text)
                when Code::STOREL_2
                    vm_store_local_2(is.text)
                when Code::LOADL
                    vm_load_n(is.text,is.value.as(Intnum))
                when Code::LOADL_0
                    vm_load_0(is.text)
                when Code::LOADL_1
                    vm_load_1(is.text)
                when Code::LOADL_2
                    vm_load_2(is.text)
                when Code::LOADV
                    vm_load_v(is.text)
                when Code::GETC
                    vm_get_c(is.text)
                when Code::LOADC
                    vm_load_c(is.text)
                when Code::PUT_CLASS
                    vm_put_class(is.text,is.jump.as(Bytecode))
                when Code::PUT_MODULE
                    vm_put_module(is.text,is.jump.as(Bytecode))
                when Code::LEAVE
                    vm_leave
                when Code::PUT_STATIC_METHOD
                    vm_put_static_method(is.text,is.method.as(LcMethod))
                when Code::PUT_INSTANCE_METHOD
                    vm_put_instance_method(is.text,is.method.as(LcMethod))
                when Code::LOADG
                    vm_load_g(is.text)
                when Code::STOREG
                    vm_store_g(is.text)
                when Code::ARY_NEW
                    vm_ary_new(is.value.as(Intnum))
                when Code::IRANGE_NEW
                    vm_range_new(true)
                when Code::ERANGE_NEW
                    vm_range_new(false)
                when Code::MX_NEW
                    vm_mx_new(is.value.as(Intnum),is.opt_v)
                when Code::NEW_OBJ
                    vm_new_obj
                when Code::OPT_CALL_INIT
                    vm_opt_call_init(is.argc,is.block)
                when Code::PUSHDUP
                    if @sp == 0
                        raise VMerror.new("(VM attempted to duplicate a missing object)")
                    else
                        obj = pop 
                        push(obj)
                        push(obj)
                    end 
                when Code::YIELD
                    vm_call_block(is.argc)
                when Code::JUMP
                    fm    = current_frame
                    fm.pc = is.jump.as(Bytecode)
                when Code::JUMPF
                    vm_jumpf(is.jump.as(Bytecode))
                when Code::JUMPT
                    vm_jumpt(is.jump.as(Bytecode))
                when Code::EQ_CMP
                    obj1 = pop
                    obj2 = pop
                    res = internal.lc_obj_match(obj2,obj1)
                    push(res)
                when Code::SET_C_T
                    catch_t               = is.catch_t.as(CatchTable)
                    current_frame.catch_t = catch_t
                    LibC.setjmp(catch_t.buff)
                    push_shared_frame
                    ErrHandler.exception_handler = 1
                when Code::CLEAR_C_T
                    pc = current_frame.pc 
                    vm_pop_frame
                    fm         = current_frame
                    fm.pc      = pc 
                    fm.catch_t = nil
                    ErrHandler.exception_handler = -1
                when Code::STOREC
                    vm_store_c(is.text)
                when Code::PUSHANS 
                    ans = current_frame.scp.ans
                    push(ans)
                when Code::HASH_NEW
                    vm_hash_new(is.argc)
                when Code::SYMBOL_NEW 
                    obj = internal.build_symbol(is.text)
                    push(obj)
                when Code::NEW_SVAR
                    v = Internal::Variable.new(is.text)
                    push(internal.build_fake_fun(v))
                when Code::NEW_SNUM
                    n = Internal::Snumber.new(is.value.as(IntnumR))
                    push(internal.build_fake_fun(n))
                when Code::S_SUM
                    right = pop
                    left  = pop
                    s     = internal.s_sum(left,right)
                    push(internal.build_fake_fun(s))
                when Code::S_SUB
                    right = pop
                    left  = pop
                    s     = internal.s_sub(left,right)
                    push(internal.build_fake_fun(s))
                when Code::S_PROD
                    right = pop
                    left  = pop
                    s     = internal.s_prod(left,right)
                    push(internal.build_fake_fun(s))
                when Code::S_DIV
                    right = pop
                    left  = pop
                    s     = internal.s_div(left,right)
                    push(internal.build_fake_fun(s))
                when Code::S_POW
                    right = pop
                    left  = pop
                    s     = internal.s_power(left,right) 
                    push(internal.build_fake_fun(s))
                when Code::S_INVERT
                    obj = pop
                    s   = internal.s_invert(obj)
                    push(internal.build_fake_fun(s))
                when Code::NEW_FUNC
                    tmp = pop
                    tmp = internal.build_function(tmp) if tmp.is_a? Internal::FakeFun
                    push(tmp)
            end
            if ErrHandler.handled_error?
                vm_handle_error(ErrHandler.error.as( LcVal))
            end
            if @quit
                @quit = false
                return Null
            end
            
            if !@to_replace.nil?
                @to_replace = internal.inline_iseq(@to_replace.as(Bytecode),is)
            end
            is = fetch
            if !@to_replace.nil?
                current_frame.pc = @to_replace.as(Bytecode)
                @to_replace = nil 
            end
        end
    end

    protected def get_last_is(is : Bytecode)
        if is.code.to_s.includes? "CALL"
            argc = is.argc 
            (argc + 2).times do |i|
                is = is.prev.as(Bytecode)
            end
            return is
        else
            raise VMerror.new("(failed to replace bytecode)")
        end
    end

# Call methods

    @[AlwaysInline]
    protected def vm_arity_check(argc1 : Intnum, argc2 : Intnum)
        if !(argc1.abs >= argc2)
            lc_raise(LcArgumentError,convert(:few_args) % {argc1.abs,argc2})
            return false 
        end 
        return true
    end

    @[AlwaysInline]
    protected def vm_get_args(argc, self_only = false)
        argv = StaticArray( LcVal,4).new(Null)
        j    = -1
        (argc + 1).downto 1 do |i|
            {% if flag?(:vm_debug) %}
                puts "getting arg at #{@sp - i} (stack level: #{@sp})"
            {% end %}
            argv[j += 1] = @stack[@sp - i]
            break if self_only
        end
        return argv
    end

    protected def vm_get_py_args(argc)
        return @stack.shared_copy(@sp - argc, argc)
    end

    @[AlwaysInline]
    protected def vm_handle_instance_method_exception(code : Intnum,owner : Structure)
        case code
            when 0
                lc_raise(LcNoMethodError,convert(:no_method) % owner.name)
            when 1
                lc_raise(LcNoMethodError,convert(:protected_method) % owner.name)
            when 2
                lc_raise(LcNoMethodError,convert(:private_method) % owner.name)
        end
    end

    @[AlwaysInline]
    protected def vm_handle_static_method_exception(owner : Structure)
        s_type = (owner.type == SType::CLASS) ? "Class" : "Module"
        lc_raise(LcNoMethodError,convert(:no_s_method) % {owner.name,s_type})
    end

    @[AlwaysInline]
    protected def vm_fetch_instance_method(obj_class : Structure,name : String)
        method = internal.seek_method(obj_class,name)
        if !(method.is_a? LcMethod)
            vm_handle_instance_method_exception(method.as(Intnum),obj_class)
            return nil 
        end
        return method.as(LcMethod)
    end

    @[AlwaysInline]
    protected def vm_fetch_instance_method_with_context(obj_class : Structure,name : String)
        context = get_context
        method  = internal.seek_method(context,name,true)
        if !(method.is_a? LcMethod)
            vm_handle_instance_method_exception(method.as(Intnum),obj_class)
            return nil 
        end
        return method.as(LcMethod)
    end

    @[AlwaysInline]
    protected def vm_fetch_static_method(receiver : Structure,name : String)
        method = internal.seek_static_method(receiver,name)
        if !(method.is_a? LcMethod)
            vm_handle_static_method_exception(receiver)
            return nil
        end
        return method.as(LcMethod)
    end

    @[AlwaysInline]
    protected def fetch_call_method(receiver :  LcVal, name : String)
        if receiver.is_a? Structure
            return vm_fetch_static_method(receiver,name)
        else
            return vm_fetch_instance_method_with_context(class_of(receiver),name)
        end
    end

    @[AlwaysInline]
    protected def fetch_method(receiver :  LcVal, name : String)
        if receiver.is_a? Structure
            return vm_fetch_static_method(receiver,name)
        else
            return vm_fetch_instance_method(class_of(receiver),name)
        end
    end

    @[AlwaysInline]
    protected def vm_get_receiver(argc)
        tmp = @stack[@sp - argc - 1]
        return tmp
    end

    @[AlwaysInline]
    protected def vm_call_method(method : LcMethod,argc : Intnum)
        m_arity = method.arity
        return nil unless vm_arity_check(argc,m_arity)
        case method.type
            when  LcMethodT::INTERNAL
                @internal = true
                if m_arity < 0
                    argv    = vm_get_args(argc,true)
                    argv[1] = @stack.shared_copy(@sp - argc,argc).as( LcVal)
                else
                    argv  = vm_get_args(argc)
                end
                value = internal_call(method.code.as(LcProc),argv,m_arity)
                push(value.as( LcVal))
                vm_return_internal
            when LcMethodT::USER
                @internal = false
                call_usr(method,argc)
            when LcMethodT::PYTHON
                @internal = true
                argv  = vm_get_py_args(argc)
                value = call_python(method,argv)
                push(value.as( LcVal))
                vm_return_internal
            else
                lc_bug("Invalid method type received")
        end
    end

    protected def vm_call(name : String, argc : Intnum)
        {% if flag?(:vm_debug) %}
            puts "calling: #{name}".colorize :yellow
        {% end %}
        CallTracker.push_track(filename,line,name)
        selfr  = vm_get_receiver(argc)
        method = fetch_call_method(selfr,name)
        if method
            vm_push_new_frame(selfr,method.owner.as(Structure),argc)
            vm_call_method(method,argc)
        end
    end

    protected def vm_m_call(name : String, argc : Intnum)
        {% if flag?(:vm_debug) %}
            puts "calling method: #{name}".colorize :yellow
        {% end %}
        CallTracker.push_track(filename,line,name)
        receiver  = vm_get_receiver(argc)
        method    = fetch_method(receiver,name)
        if method
            vm_push_new_frame(receiver,method.owner.as(Structure),argc)
            vm_call_method(method,argc)
        end
    end

    protected def vm_set_block(block : LcBlock)
        fm          = current_frame
        scp         = fm.scp
        block.scp   = scp 
        block.me    = fm.me
        scp.lcblock = block 
    end

    protected def vm_call_with_block(name : String,argc : Intnum, block : LcBlock)
        vm_set_block(block)
        vm_call(name,argc)
    end

    protected def vm_m_call_with_block(name : String,argc : Intnum, block : LcBlock)
        vm_set_block(block)
        vm_m_call(name,argc)
    end

    @[AlwaysInline]
    protected def vm_return_internal
        {% if flag?(:vm_debug) %}
            puts "Internal function #{CallTracker.current_call_name} returned"
        {% end %}
        value = pop 
        argc  = vm_pop_frame
        discard_arguments(argc + 1)
        CallTracker.pop_track
        push(value)
    end

    protected def vm_return
        {% if flag?(:vm_debug) %}
            puts "Returning from method: #{CallTracker.current_call_name};\
            frame: #{current_frame.type}".colorize(:yellow)
        {% end %}
        value       = pop
        @handle_ret = current_frame.handled_ret
        argc        = vm_pop_frame
        discard_arguments(argc + 1)
        CallTracker.pop_track
        vm_pop_location
        push(value)
        current_frame.scp.lcblock = nil
    end

    
    private def get_arg(n)
        argc = current_frame.argc
        if argc > n && argc > 0
            return @stack[@sp - argc + n]
        else
            return nil
        end
    end

    protected def vm_load_call_args(args : FuncArgSet,argc : Intnum)
        count = 0
        args.arg.each do |name|
            value = get_arg(count)
            if value
                store_local(name,value)
            elsif
                lc_raise(LcArgumentError,convert(:few_args) % {count,argc})
                return nil
            end
            count += 1
        end 
        args.opt.each do |arg|
            value = get_arg(count)
            name  = arg.name
            if value
                store_local(name,value)
            else
                pc  = current_frame.pc 
                current_frame.pc = arg.optcode
                vm_run_bytecode
                current_frame.pc = pc 
            end
            count += 1
        end
        if !(name = args.block).empty? 
            if (block = vm_get_block)
                proc = internal.lincas_block_to_proc(block)
                store_local(name,proc)
            else
                store_local(name, Null)
            end
        end
        return true
    end

    protected def store_local(name : String,value :  LcVal)
        scp = current_scope
        scp.set_var(name,value)
    end

# Store 

    protected def vm_store_local_0(name : String)
        value = pop
        scp   = current_scope
        scp.set_var(name,value)
        push(value)
    end

    protected def vm_store_local_1(name : String)
        value = pop
        scp   = current_scope.previous.as(Scope)
        scp.set_var(name,value)
        push(value)
    end

    protected def vm_store_local_2(name : String)
        value = pop
        scp   = current_scope.previous.as(Scope).previous.as(Scope)
        scp.set_var(name,value)
        push(value)
    end

    protected def vm_store_local(name : String, depth : Intnum)
        value = pop 
        scp   = current_scope
        depth.times do |i|
            scp = scp.previous.as(Scope)
        end
        scp.set_var(name,value)
        push(value)
    end

    protected def vm_store_g(name : String)
        value    = pop
        receiver = pop
        if !has_flag receiver,FAKE
            receiver.data.addVar(name,value)
        else
            lc_bug("Fake object for STORE_G instruction")
        end
        push(value)
    end

    protected def vm_store_c(name : String)
        value = pop
        obj   = pop
        klass = class_of(obj)
        const = internal.lc_seek_const(klass,name)
        if const 
            lc_raise_1(LcNameError,"Constant already defined")
        else
            internal.lc_define_const(klass,name,value)
        end
        push(obj)
    end

# load 

    protected def vm_load_v(name : String)
        scp   = current_scope
        value = scp.get_var(name)
        if value 
            push(value)
        else 
            klass = class_of(current_frame.me)
            const = internal.lc_seek_const(klass,name)
            if const
                push(const.as( LcVal))
            else
                lc_raise_1(LcNameError,convert(:undefined_id) % {name,klass.path.to_s})
                push(Null)
            end
        end 
    end
    
    protected def vm_load_n(name : String, depth : Intnum)
        scp = current_scope
        depth.times do |i|
            scp = scp.previous.as(Scope)
        end
        value = scp.get_var(name)
        if value 
            push(value)
        else 
            lc_raise_1(LcNameError,convert(:undef_var) % name)
            push(Null)
        end
    end

    protected def vm_load_0(name : String)
        scp   = current_scope
        value = scp.get_var(name)
        if value 
            push(value)
        else 
            lc_raise_1(LcNameError,convert(:undef_var) % name)
            push(Null)
        end
    end

    protected def vm_load_1(name : String)
        scp   = current_scope.previous.as(Scope)
        value = scp.get_var(name)
        if value 
            push(value)
        else 
            lc_raise_1(LcNameError,convert(:undef_var) % name)
            push(Null)
        end
    end

    protected def vm_load_2(name : String)
        scp   = current_scope.previous.as(Scope).previous.as(Scope)
        value = scp.get_var(name)
        if value 
            push(value)
        else 
            lc_raise_1(LcNameError,convert(:undef_var) % name)
            push(Null)
        end
    end

    protected def vm_load_c(name : String)
        selfr = pop
        if !(selfr.is_a? Structure)
            klass = class_of(selfr)
        else
            klass = selfr.as(Structure)
        end
        const = internal.lc_seek_const(klass,name)
        if const
            push(const)
        else
            path = klass.path
            lc_raise_1(LcNameError,convert(:undef_const_2) % {name,path.empty? ? klass.name : path.to_s})
            push(Null)
        end
    end

    protected def vm_load_g(name : String)
        obj   = pop
        value = obj.data.getVar(name)
        if value
            push(value)
        else 
            push(Null)
        end
    end


    protected def vm_get_c(name : String)
        prev = pop
        if !(prev.is_a? Structure)
            lc_raise_1(LcNameError,convert(:not_a_struct) % name)
            push(Null)
            return nil
        end
        prev = prev.as(Structure)
        const = internal.lc_seek_const(prev,name)
        if const 
            push(const.as( LcVal))
        else
            lc_raise_1(LcNameError,convert(:undef_const_2) % {name,prev.path.to_s})
            push(Null)
        end
    end

    protected def vm_put_class(name : String,bytecode : Bytecode)
       parent  = pop 
       obj     = pop
       p_scope = class_of(obj)
       klass   = vm_create_class(name,parent,p_scope)
       if klass
           vm_push_new_frame(klass,klass,0,FrameType::CLASS_FRAME)
           current_frame.pc = bytecode
           CallTracker.push_track(filename,line,"<class:%s>" % name)
       end
    end

    protected def vm_create_class(name : String,parent :  LcVal,scope : Structure)
        p_def = internal.lc_seek_const(scope,name)
        if p_def.is_a? LcClass
            if has_flag p_def, FROZEN
                lc_raise_1(LcFrozenError,convert(:frozen_class))
                return nil 
            end 
            return p_def
        elsif p_def.nil?
            path  = scope.path
            klass = internal.lc_build_class(name,path.addName(name))
            return nil unless vm_set_parent(klass,parent)
            klass.symTab.parent = scope.symTab 
            scope.symTab.addEntry(name,klass)
            return klass
        else 
            lc_raise_1(LcTypeError,convert(:not_a_class) % name)
            return nil
        end
    end

    protected def vm_set_parent(klass : LcClass,parent :  LcVal)
        if !(parent.is_a? Structure) && parent != Null
            lc_raise_1(LcTypeError,convert(:no_parent) % internal.lc_typeof(parent))
            push(klass)
            return nil
        end 
        if klass.parent && parent != Null 
            lc_raise_1(LcTypeError,convert(:superclass_err) % klass.name)
            return nil
        elsif !(klass.parent) && parent == Null 
            internal.lc_set_parent_class(klass,Internal::Obj)
            return true
        end
        return true if parent == Null
        internal.lc_set_parent_class(klass,parent.as(LcClass))
        return true
    end

    protected def vm_put_module(name : String, bytecode : Bytecode)
        obj     = pop
        p_scope = class_of(obj)
        mod     = vm_create_module(name,p_scope)
        if mod 
           vm_push_new_frame(mod,mod,0,FrameType::CLASS_FRAME)
           current_frame.pc = bytecode
           CallTracker.push_track(filename,line,"<module:%s>" % name)
        end
    end

    protected def vm_create_module(name : String, scope : Structure)
        p_def = internal.lc_seek_const(scope,name)
        if p_def.is_a? LcModule
            if has_flag p_def, FROZEN
                lc_raise_1(LcFrozenError,convert(:frozen_module))
                return nil 
            end 
            return p_def
        elsif p_def.nil?
            path  = scope.path
            mod   = internal.lc_build_module(name,path.addName(name))
            mod.symTab.parent = scope.symTab 
            scope.symTab.addEntry(name,mod)
            return mod
        else 
            lc_raise_1(LcTypeError,convert(:not_a_module) % name)
            return nil
        end
    end

    protected def vm_leave
        {% if flag?(:vm_debug) %}
            puts "Leaving frame #{current_frame.type};\
            call: #{CallTracker.current_call_name}".colorize(:green)
        {% end %}
        fm = current_frame
        vm_pop_frame
        frame_t = fm.type
        if frame_t == FrameType::CLASS_FRAME
            me = fm.me 
            CallTracker.pop_track
            vm_set_ans(me)
        elsif frame_t == FrameType::MAIN_FRAME
            vm_set_ans(fm.scp.ans)
            vm_pop_location
            @quit = true
        else 
            raise VMerror.new("VM was asked to leave a wrong frame (#{frame_t})")
        end
    end

    protected def vm_next 
        {% if flag?(:vm_debug) %}
            puts "Returning from block; frame: #{current_frame.type}".colorize(:yellow)
        {% end %}
        value       = pop
        @handle_ret = current_frame.handled_ret
        argc        = vm_pop_frame
        discard_arguments(argc)
        CallTracker.pop_track
        vm_pop_location
        push(value)
    end

    protected def vm_get_block
        scp = current_scope
        while scp && scp.type == SCPType::BLOCK_SCP
            scp = previous_scope_of(scp)
        end
        return nil unless scp 
        scp = previous_scope_of(scp)
        if scp 
            return scp.lcblock
        end
        return nil
    end

    protected def vm_call_block(argc : Intnum)
        block = vm_get_block
        fm    = current_frame
        if block 
            CallTracker.push_track(filename,line,"<block>")
            _self = block.me
            vm_push_new_frame(_self,class_of(_self),argc,block.scp.as(Scope))
            fm    = current_frame
            fm.pc = block.body
            vm_load_call_args(block.args,argc)
        else 
            lc_raise(LcArgumentError,convert(:no_block) % "(yield)")
        end
    end

    protected def vm_put_static_method(name : String,method : LcMethod)
        object       = pop
        klass        = class_of(object)
        method.owner = klass
        klass.statics.addEntry(name,method)
        push(object)
    end

    protected def vm_put_instance_method(name : String,method : LcMethod)
        object       = pop
        klass        = class_of(object)
        method.owner = klass
        klass.methods.addEntry(name,method)
        push(object)
    end

    protected def vm_ary_new(size : Intnum)
        ary = internal.new_ary 
        i   = 0
        while i < size 
            obj = pop
            internal.lc_ary_push(ary,obj)
            i += 1
        end 
        push(ary)
    end

    protected def vm_range_new(inclusive)
        right = pop
        left  = pop
        range = internal.build_range(left,right,inclusive)
        push(range)
    end

    protected def vm_mx_new(rws : Intnum, cls : Intnum)
        i = 0
        j = 0
        mx = internal.build_matrix(rws,cls)
        while i < rws 
            while j < cls 
                value = pop
                internal.lc_set_matrix_index(mx,i,j,value)
                j += 1
            end 
            i += 1 
            j  = 0
        end
        push(mx)
    end

    protected def vm_hash_new(size : IntnumR)
        hash = internal.build_hash
        size.times do
            value = pop
            key   = pop
            internal.lc_hash_set_index(hash,key,value)
        end
        push(hash)
    end

    protected def vm_new_obj
        CallTracker.push_track(filename,line,"new")
        klass = pop
        if !(klass.is_a? LcClass)
            lc_raise(LcTypeError,"Argument of new must be a class (#{internal.lc_typeof(klass)} given)")
            return nil 
        end
        obj   = internal.lc_new_object(klass)
        push(obj)
        CallTracker.pop_track
    end

    protected def vm_opt_call_init(argc : Intnum,block : LcBlock? = nil)
        init = "init"
        obj  = vm_get_receiver(argc)
        if internal.lc_obj_responds_to?(obj,init)
            if block
                vm_m_call_with_block(init,argc,block)
            else
                vm_m_call(init,argc)
            end
        end
    end

    protected def vm_jumpf(code : Bytecode)
        obj = pop
        if !test(obj)
            fm    = current_frame
            fm.pc = code 
        end
    end

    protected def vm_jumpt(code : Bytecode)
        obj = pop
        if test(obj)
            fm    = current_frame
            fm.pc = code 
        end
    end


    protected def lc_raise_1(code,msg)
        backtrace = String.build do |io|
            io << "line: " << line    << '\n'
            io << "in: "   << filename << '\n'
            io << CallTracker.get_backtrace
        end
        error_body = String.build do |str|
            str << '\n'
            str << code
            str << ": "
            str << msg
        end
        error = internal.build_error(code,msg,backtrace) 
        ErrHandler.handle_error(error)
    end


    def lc_raise(code,msg)
        backtrace = CallTracker.get_backtrace
        error_body = String.build do |str|
            str << '\n'
            str << code
            str << ": "
            str << msg
        end
        error = internal.build_error(code,msg,backtrace) 
        ErrHandler.handle_error(error)
    end

    def lc_raise(error :  LcVal)
        error = error.as(LcError)
        error.backtrace = CallTracker.get_backtrace
        ErrHandler.handle_error(error)
    end 

    def get_block 
        return vm_get_block
    end

    def lc_yield(*args :  LcVal)
        vm_push_args(args)
        if block_given?
            vm_call_block(args.size)
            set_handle_ret_flag
            return vm_run_bytecode.as( LcVal)
        else 
            lc_raise(LcArgumentError,convert(:no_block))
        end
    end

    def lc_call_fun(receiver :  LcVal, method : String, *args)
        push(receiver)
        vm_push_args(args)
        vm_m_call(method,args.size)
        if @internal
            return pop
        else
            set_handle_ret_flag
            return vm_run_bytecode
        end
    end

    def call_method(method : Internal::Method, argv : Ary | Array(LcVal))
        m    = method.method
        rec  = method.receiver
        push(rec)
        vm_push_args(argv)
        CallTracker.push_track(filename,line,m.name)
        vm_push_new_frame(rec,m.owner.as(Structure),argv.size)
        vm_call_method(m,m.arity)
        if @internal
            return pop
        else
            set_handle_ret_flag
            return vm_run_bytecode
        end
    end

    def call_proc(proc : Internal::LCProc, argv : Ary)
        vm_push_args(argv)
        _self = proc.me 
        args  = proc.args
        code  = proc.code
        scp   = proc.scp 
        argc  = argv.size
        CallTracker.push_track(filename,line,internal.lincas_obj_to_s(proc))
        vm_push_new_frame(_self,class_of(_self),argc,scp,FrameType::PROC_FRAME)
        current_frame.pc = code
        vm_load_call_args(args,argc)
        set_handle_ret_flag
        return vm_run_bytecode
    end

    protected def vm_push_args(args)
        args.each do |arg|
            push(arg)
        end 
    end

    @[AlwaysInline]
    def block_given?
        !!vm_get_block
    end

    @[AlwaysInline]
    protected def get_catch_t
        catch_t = current_frame.catch_t
        while !catch_t && @vm_fp > 0
            vm_pop_frame
            catch_t = current_frame.catch_t 
        end 
        if !catch_t
            raise VMerror.new("Catch table not found")
        end 
        return catch_t
    end

    protected def vm_handle_error(error :  LcVal)
        if ErrHandler.exception_handler?
            catch_t = get_catch_t
            name    = catch_t.var_name
            iseq    = catch_t.code 
            if name 
                store_local(name,ErrHandler.error.as(LcError))
            end 
            ErrHandler.handle_error(nil)
            ErrHandler.exception_handler = -1
            current_frame.pc             = iseq
            LibC.longjmp(catch_t.buff,1)
        else
            error = ErrHandler.error.as(LcError)
            msg   = String.build do |io|
                io << error.body 
                io << '\n' << error.backtrace
            end
            sendMsg(Msg.new(MsgType::RUNTIME_ERROR,[msg]))
        end
    end

    def print_end_backtrace
        backtrace = CallTracker.get_backtrace
        sendMsg(Msg.new(MsgType::BACKTRACE,[backtrace]))
    end

    def vm_replace_iseq(iseq : Bytecode)
        @to_replace = iseq
    end

    def get_current_filedir
        return File.dirname(filename)
    end

    def get_current_filename
        return filename 
    end

    def get_current_call_line
        return CallTracker.current_call_line 
    end

end

module LinCAS
    Exec = VM.new
end