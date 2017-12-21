
# Copyright (c) 2017 Massimiliano Dal Mas
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

class LinCAS::Eval < LinCAS::MsgGenerator

    alias    LcKernel = Internal::LcKernel
    
    macro convert(err)
        LinCAS.convert_error({{err}})
    end

    macro internal
        LinCAS::Internal
    end

    macro find(name)
        Id_Tab.lookUp({{name}})
    end

    macro find_local(name)
        Id_Tab.lookUpLocal({{name}})
    end

    macro reopen(klass)
        Id_Tab.enterScope({{klass}}.as(Structure))
    end

    macro exit_scope
        Id_Tab.exitScope
    end

    macro current_scope
        Id_Tab.getCurrent
    end

    macro unpack_name(node)
        {{node}}.getAttr(NKey::ID)
    end

    macro send_msg(msg)
        sendMsg(Msg.new(MsgType::RUNTIME_ERROR,[{{msg}}]))
    end

    macro push_frame(filename,line,name)
        @callstack.pushFrame({{filename}}.as(String),{{line}}.as(Intnum),{{name}}.as(String))
    end 

    macro pop_frame
        @callstack.popFrame 
    end

    macro bind_method(scope,name,method)
        {{scope}}.methods.addEntry({{name}},{{method}})
    end

    macro call_internal(name,arg)
        internal.{{name.id}}({{arg}})
    end

    macro call_internal_1(name,*arg)
        internal.{{name.id}}({{arg[0]}},{{arg[1]}})
    end 

    macro call_internal_2(name,*args)
        internal.{{name.id}}({{arg[0]}},{{arg[1]}},{{arg[3]}})
    end 

    macro call_internal_n(name,*args)
        call_internal({{name}},{{args}})
    end

    def initialize
        @callstack  = CallStack.new
        @msgHandler = MsgHandler.new
        @try        = 0
    end

    def messageHandler
        @msgHandler
    end

    def eval(program : Node?)
        if program
            push_frame(find_file(program.as(Node)),0,"Main")
            eval_stmt(program) 
            pop_frame
        end
        puts
    end

    protected def eval_stmt(node : Node)
        case node.type
            when NodeType::PROGRAM
                return eval_program(node)
            when NodeType::READS
                return eval_reads(node)
            when NodeType::PRINT, NodeType::PRINTL
                return eval_print(node)
            when NodeType::CLASS 
                eval_class(node)
            when NodeType::MODULE 
                eval_module(node)
            when NodeType::VOID
                eval_void(node)
            # when NodeType::WHILE
            # when NodeType::UNTIL
            # when NodeTypee::IF
            # when NodeType::SELECT
        end
    end

    protected def eval_program(node : Node) : Nil
        branches = node.getBranches
        branches.each do |branch|
            eval_stmt(branch)
        end
    end

    protected def eval_reads(node)
        return LcKernel.in
    end

    protected def eval_print(node)
        args = node.getBranches
        case node.type
            when NodeType::PRINT
                (0...args.size).each do |i|
                    LcKernel.out(eval_exp(args[i]))
                end
            when NodeType::PRINTL
                (0...args.size).each do |i|
                    LcKernel.outl(eval_exp(args[i]))
                end
        end
    end

    protected def eval_exp(node : Node)
        case node.type
            when NodeType::STRING
                string = node.getAttr(NKey::VALUE)
                return internal.build_string(string)
            when NodeType::TRUE
                return Internal::LcTrue
            when NodeType::FALSE
                return Internal::LcFalse
            when NodeType::INT
                return internal.num2int(node.getAttr(NKey::VALUE))
            when NodeType::FLOAT
                return internal.num2float(node.getAttr(NKey::VALUE))
            when NodeType::ARRAY

            when NodeType::MATRIX

            when NodeType::SYMBOLIC

            when NodeType::CALL

            when NodeType::METHOD_CALL

            when NodeType::NEW
                
        else
            return eval_bin_op(node)
        end
    end

    macro calculate_binary(node)
        branches = {{node}}.getBranches
        left     = branches[0]
        right    = branches[1]
        l_val    = eval_exp(left).as(Internal::Value)
        r_val    = eval_exp(right).as(Internal::Value)
    end

    protected def eval_bin_op(node : Node)
        case node.type
            when NodeType::SUM
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value 
                calculate_binary(node)
                return call_binary(node,l_val,"+",r_val)
            when NodeType::SUB
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value  
                calculate_binary(node)
                return call_binary(node,l_val,"-",r_val)
            when NodeType::MUL
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value  
                calculate_binary(node)
                return call_binary(node,l_val,"*",r_val)
            when NodeType::FDIV
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value  
                calculate_binary(node)
                return call_binary(node,l_val,"/",r_val)
            when NodeType::IDIV
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value  
                calculate_binary(node)
                return call_binary(node,l_val,"\\",r_val)
            when NodeType::MOD
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value 
                calculate_binary(node)
                return call_binary(node,l_val,"%",r_val)
            when NodeType::AND
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value  
                calculate_binary(node)
                return call_binary(node,l_val,"&&",r_val)
            when NodeType::OR 
                l_val = uninitialized Internal::Value 
                r_val = uninitialized Internal::Value  
                calculate_binary(node)
                return call_binary(node,l_val,"||",r_val)
            when NodeType::NOT
                arg     = node.getBranches[0]
                arg_val = eval_stmt(arg)
                return call_single(node,arg,"!")
            when NodeType::INVERT
                arg     = node.getBranches[0]
                arg_val = eval_stmt(arg)
                return call_single(node,arg,"invert")
        else
            lc_raise(LcInternalError,convert(:wrong_node),node)
        end
        # Should never get here
        nil
    end

    protected def eval_call(node : Node)
        
    end

    protected def eval_method_call(node : Node)
        
    end

    protected def call_binary(node : Node,receiver,name : String,arg)
        push_frame(find_file(node),find_line(node),name)
        static = receiver.is_a? Structure
        method = internal.seek_method(receiver,name)
        if method
            method = method.as(MethodEntry)
            arity = method.arity
            if arity != 1
                lc_raise(LcArgumentError,convert(:few_args) % {arity,1})
                return nil
            end
            if static
                unless method.static == true
                    s_type = (receiver.is_a? ClassEntry) ? "Class" : "Module"
                    lc_raise(LcNoMethodError,convert(:no_s_method) % {receiver.path.to_s,s_type})
                end
                # push_empty_data
                if method.internal
                    return call_internal(method,arg)
                else 
                    # To Implement
                end 
            else 
                if method.static == true
                    lc_raise(LcNoMethodError,convert(:no_method) % receiver.class.name)
                end
                if method.internal
                    return call_internal(receiver,arg)
                else 
                    # To implement
                end
            end
        else 
            if static
                s_type = (receiver.is_a? ClassEntry) ? "Class" : "Module"
                lc_raise(LcNoMethodError,convert(:no_s_method) % {receiver.path.to_s,s_type})
            else 
                lc_raise(LcNoMethodError,convert(:no_method) % receiver.class.name)
            end
            return nil
        end
    end 

    protected def call_single(node,receiver,name)
        
    end

    protected def eval_class(node : Node)
        namespace   = node.getAttr(NKey::NAME).as(Node)
        parent      = node.getAttr(NKey::PARENT)
        body        = node.getBranches[0]
        name        = namespace.as(Node).getBranches
        if name.size == 1
            name  = unpack_name(name[0])
            push_frame(find_file(node),find_line(node),name)
            klass = find(name)
            klass = define_class(klass,name)
        else
            scope = eval_namespace(namespace.as(Node),false)
            reopen(scope)
            name  = unpack_name(name.last)
            push_frame(find_file(node),find_line(node),name)
            klass = find_local(name)
            klass = define_class(klass,name)
        end
        if klass.as(ClassEntry).parent.nil? && parent
            parent = eval_namespace(parent.as(Node))
            lc_raise(
                LcTypeError,convert(:not_a_class) % stringify_namespace(namespace),node
            ) unless parent.is_a? ClassEntry
            internal.lc_set_parent_class(klass.as(ClassEntry),parent.as(ClassEntry)) 
        elsif !klass.as(ClassEntry).parent.nil? && parent
            lc_raise(LcTypeError,convert(:superclass_err) % name)
        else
            internal.lc_set_parent_class(klass.as(ClassEntry),Internal::Obj)
        end
        eval_body(body)
        exit_scope
        pop_frame
    end

    protected def define_class(klass,name)
        if klass.is_a? ClassEntry
            reopen(klass)
            return klass
        elsif !klass.nil?
            lc_raise(LcTypeError,convert(:not_a_class) % name)
        else
            return internal.lc_build_class(name.as(String))
        end
        nil 
    end

    macro check_name(name,oldName)
        if {{name}}.nil?
            lc_raise(LcNameError,convert(:undefined_const) % {{oldName}},node)
        elsif ! {{name}}.is_a? Structure
            lc_raise(LcTypeError,convert(:not_a_struct) % {{oldName}},node)
        end 
    end

    protected def eval_namespace(node : Node, last = true)
        names = node.getBranches
        first = unpack_name(names[0])
        name  = find(first)
        check_name(name,first)
        (1...names.size - 1).each do |n|
           id   = unpack_name(names[n])
           name = name.as(Structure).symTab.lookUp(id)
           check_name(name,id)
        end
        name = name.as(Structure).symTab.lookUp(unpack_name(names.last)) if last && names.size > 1
        return name 
    end

    protected def eval_module(node : Node)
        namespace = node.getAttr(NKey::NAME)
        body      = node.getBranches
        name      = namespace.as(Node).getBranches
        if name.size == 1
            name = unpack_name(name[0])
            mod  = find(name)
            mod  = define_module(mod,name)
            push_frame(find_file(node),find_line(node),name)
        else
            scope = eval_namespace(namespace.as(Node),false)
            reopen(scope)
            name = unpack_name(name.last)
            mod  = find_local(name)
            mod  = define_module(mod,name)
            push_frame(find_file(node),find_line(node),name)
        end 
        eval_body(body[0])
        exit_scope
        pop_frame
    end

    protected def define_module(mod,name)
        if mod.is_a? ModuleEntry
            reopen(mod)
        elsif !mod.nil?
            lc_raise(LcTypeError,convert(:not_a_module) % name)
        else
            return internal.lc_build_module(name.as(String))
        end 
        nil
    end

    protected def eval_void(node : Node) : ::Nil
        name     = node.getAttr(NKey::NAME).as(Node)
        visib    = node.getAttr(NKey::VOID_VISIB)
        branches = node.getBranches
        args     = branches[0]
        arity    = args.getAttr(NKey::VOID_ARITY).as(Intnum)
        body     = branches[1]
        static   = false
        if name.type == NodeType::SELF
            voidName = unpack_name(name.getBranches[0]).as(String)
            receiver = current_scope
            static   = true
        else
            voidName = unpack_name(name).as(String)
            receiver = name.getAttr(NKey::RECEIVER)
            if receiver 
                if receiver.as(Node).type == NodeType::NAMESPACE
                    receiver = eval_namespace(receiver.as(Node))
                    static   = true
                    return nil unless receiver
                elsif receiver 
                    r_name   = unpack_name(receiver.as(Node))
                    receiver = find(r_name)
                    if !receiver
                        lc_raise(LcNameError,convert(:undefined_const) % r_name,node)
                        return nil
                    end
                    static = true
                end
            else 
                receiver = current_scope.as(Structure)
            end 
        end
        if {VoidVisib::PUBLIC,nil}.includes? visib
            if static
                method = internal.lc_define_static_usr_method(
                    voidName,args,receiver.as(Structure),body,arity
                )
            else 
                method = internal.lc_define_usr_method(
                    voidName,args,receiver.as(Structure),body,arity
                )
            end
        else
            visib = visib.as(VoidVisib)
            if static
                method = internal.lc_define_static_usr_method(
                   voidName,args,receiver.as(Structure),body,arity,visib
                )
            else
                method = internal.lc_define_usr_method(
                    voidName,args,receiver.as(Structure),body,arity,visib
                )
            end
        end 
        bind_method(receiver.as(Structure),voidName,method)
        p receiver.as(Structure).name; gets
        p voidName
    end

    protected def eval_body(node : Node)
        branches = node.getBranches
        branches.each do |branch|
            eval_stmt(branch.as(Node))
        end
    end


    def lc_raise(code,msg,node)
        backtrace = build_backtrace(node) if node
        if @try == 0
            error = String.build do |err|
                err << code
                err << ": "
                err << msg
                err << '\n'
                err << backtrace
            end
            send_msg(error)
        else
        end
    end

    def lc_raise(code,msg)
        if @try == 0
            error = String.build do |str|
                str << '\n'
                str << code
                str << ": "
                str << msg 
                str << @callstack.getBacktrace
            end
            send_msg(error)
        else 
        end 
    end

    protected def build_backtrace(node : Node)
        line            = find_line(node)
        file            = find_file(node)
        callstack_trace = @callstack.getBacktrace
        return String.build do |str|
            str << '\n'
            str << "Line: "
            str << line 
            str << '\n'
            str << "In: "
            str << file 
            str << '\n'
            str << callstack_trace
        end
    end

    protected def find_line(node : Node)
        line = node.getAttr(NKey::LINE)
        while !line
            node = node.parent 
            line = node.getAttr(NKey::LINE)
        end 
        return line 
    end

    protected def find_file(node : Node)
        filename = node.getAttr(NKey::FILENAME)
        while !filename
            node     = node.parent 
            filename = node.getAttr(NKey::FILENAME)
        end 
        return filename
    end

    protected def stringify_namespace(node : Node)
        str = ""
        names = node.getBranches
        return String.build do |str|
            names.each do |el|
                str << unpack_name(el)
            end 
        end
    end
    
end

module LinCAS
    Exec = Eval.new 
end