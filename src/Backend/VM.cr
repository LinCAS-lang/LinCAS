
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

require "./VMcall_tracker"

class LinCAS::VM

    MAX_STACK_DEPTH = 2000

    alias Value   = Internal::Value
    alias ValueR  = Internal::ValueR
    Null          = Internal::Null
    LcTrue        = Internal::LcTrue
    LcFalse       = Internal::LcFalse


    private struct ObjectWrapper
        def initialize(@object : Value)
        end
        getter object
    end

    macro wrap_object(object)
        return ObjectWrapper.new({{object}})
    end

    macro unwrap_object(object)
        {{object}}.as(ObjectWrapper)object 
    end

    private class VMerror < Exception        
    end

    private class ErrorHandler
        @error : Value? = nil 
        @ex_h  = false
        getter error 

        @[AlwaysInline]
        def exception_handler?
            return @ex_h
        end

        @[AlwaysInline]
        def exception_handler=(value : Bool)
            @ex_h = value
        end

        @[AlwaysInline]
        def handled_error?
            return !!@error 
        end

        @[AlwaysInline]
        def handle_error(error : Value)
            @error = error 
        end
    end

    private class Scope
        @filename = ""

        def initialize(@selfr : Value, @context : Structure)
        end

        getter selfr,filename,context

        @vars   = Hash(String,Value).new 

        def set_var(name : String, object : Value)
            @vars[name] = object 
        end 

        def get_var(name : String)
            @vars[name]?
        end

    end

    StackValue  = ObjectWrapper | Intnum | Bytecode
    ErrHandler  = ErrHandler.new 
    CallTracker = VMcall_tracker.new

    W_true      = wrap_object(LcTrue)
    W_false     = wrap_object(LcFalse)
    W_null      = wrap_object(LcNull)

    macro current_scope
        @scopest.last 
    end

    macro push_scope(scope)
        @scopest.push(scope)
    end 

    macro pop_scope(scope)
        @scopest.pop 
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

    macro call_internal_n(method,args)
        {{method}}.call(args)
    end

    macro discard_arguments(argc)
        @sp -= {{argc}}
    end

    @[AlwaysInline]
    private def class_of(obj : Value)
        if obj.is_a? Structure 
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
                return call_internal_n(method,args)
        end
    end


    def initialize(bytecode : Bytecode)
        @stack   = [] of StackValue
        @scopest = [] of Scope
        @fp      = 0            # frame pointer
        @argc    = 0            # argument count
        @sp      = 0            # stack pointer
        @pc      = bytecode     # program count
        @scp     = 0            # scope pointer
        @line    = 0.as(Intnum)

        @filename = ""
    end

    @[AlwaysInline]
    protected def ensured_stack_space?(count)
        if @sp + count > MAX_STACK_DEPTH
            # lc_raise()
            return false 
        else 
            return true
        end

    end

    @[AlwaysInline]
    protected def push(object : StackValue)
        if ensured_stack_space? 1
            @stack[@sp] = object 
            @sp += 1
        end 
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
    protected def vm_save_current_state
        if ensured_stack_space? 3
            push(@argc)
            push(@fp)
            push(@pc)
            @fp = @sp
            return true 
        end
        return false 
    end

    @[AlwaysInline]
    protected def restore_previous_state
        @pc   = @stack[@fp - 1]
        @fp   = @stack[@fp - 2]
        @argc = @stack[@fp - 3]
        @sp   = @fp - 3

        # @filename = current_scope.filename
    end

    @[AlwaysInline]
    def error?
        return ErrHandler.handled_error?
    end

    @[AlwaysInline]
    def fetch
        tmp = @pc.nextc
        if tmp 
            @pc = tmp 
        else
            raise VMerror.new("VM failed to fetch bytecode")
        end 
    end

    @[AlwaysInline]
    def run
        obj = internal.boot_main_object
        @scopest.push(Scope.new(obj,))
        vm_run_bytecode
    end

    protected def vm_run_bytecode
        is = @pc
        loop do
            case is.code
                when Code::LINE
                    @line = is.line
                when Code::FILENAME
                    @filename = is.text
                    if current_scope.filename == ""
                        current_scope.filename = @filename
                    end
                when Code::HALT
                    exit 0
                when Code::NEXT
                    return Null 
                when Code::PUSHN
                    push(W_null)
                when Code::PUSHT
                    push(W_true)
                when Code::PUSHF
                    push(W_false)
                when Code::PUSHSELF
                    push(wrap_object(current_scope.selfr))
                when Code::PUSHINT
                    int = internal.num2int(is.value.as(Intnum))
                    push(wrap_object(int))
                when Code::PUSHFLO
                    flo = internal.num2float(is.value.as(Floatnum))
                    push(wrap_object(flo))
                when Code::POPOBJ
                    pop
                when Code::CALL
                    vm_call(is.text,is.argc)
                when Code::M_CALL
                    vm_m_call(is.text,is.argc)
            end
            if ErrHandler.handled_error?
                vm_handle_error(ErrHandler.error.as(Value))
            end
            is = fetch
        end
    end

    @[AlwaysInline]
    protected def vm_arity_check(argc1 : Intnum, argc2 : Intnum)
        if !(argc1 == argc2)
            lc_raise(LcArgumentError,convert(:few_args) % {argc1,argc2})
            return false 
        end 
        return true
    end

    @[AlwaysInline]
    protected def vm_get_args(argc)
        argv = [] of Value
        aegc.downto 1 do |i|
            argv << unwrap_object(@stack[@sp - 3 - i])
        end
        return argv
    end

    protected def vm_handle_method_exception(code : Intnum)
        
    end

    protected def vm_call(name : String, argc : Intnum)
        context = current_scope.context
        CallTracker.push_track(current_scope.filename,@line,name)
        selfr  = vm_get_self(argc)
        if selfr.is_a? Structure
            method = internal.seek_static_method(context,name)
        else 
            method = internal.seek_method(context,name)
        end
        if !method.is_a? MethodEntry
            vm_handle_method_exception(method.as(Intnum))
        else
            method = method.as(MethodEntry)
            unless vm_arity_check(argc,method.arity)
                CallTracker.pop_track 
                return 
            end
            vm_save_current_state
            if method.internal
                argv  = vm_get_args(argc) 
                value = internal_call(method,argv,argc)
                restore_previous_state
                discard_arguments
                push(wrap_object(value))
            else
                @argc = argc
                push_scope(selfr,method.as(MethodEntry).owner)
            end
        end
        CallTracker.pop_track
    end

    protected def vm_m_call(name : String, argc : Intnum)
        
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

    def lc_yield(*args : Value)

    end

    protected def vm_handle_error(error : Value)
        
    end

end