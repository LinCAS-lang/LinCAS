
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

require "./Symbol_table"

class LinCAS::Compiler

    private class CompilerError < ::Exception
    end

    
    HALT       = Bytecode.new(Code::HALT)
    Noop       = Bytecode.new(Code::NOOP)
    NEXTB      = Bytecode.new(Code::NEXTB)
    STstack    = Symbol_Table_Stack.new

    macro internal
        LinCAS::Internal
    end

    macro set_last(is1,is2)
        if {{is2}}.lastc 
            {{is1}}.lastc = {{is2}}.lastc 
        else
            {{is1}}.lastc = {{is2}}
        end
    end

    macro unpack_name(node)
        {{node}}.getAttr(NKey::ID).as(String)
    end

    macro noop
        Bytecode.new(Code::NOOP)
    end

    macro pushself 
        Bytecode.new(Code::PUSHSELF)
    end

    macro pushn 
        Bytecode.new(Code::PUSHN)
    end

    macro popobj
        Bytecode.new(Code::POPOBJ)
    end

    macro noop
        Bytecode.new(Code::NOOP)
    end

    macro leave
        Bytecode.new(Code::LEAVE)
    end

    def initialize
        @ifactory    = IntermediateFactory.new
        @block_depth = 0
    end

    @[AlwaysInline]
    protected def link(*is : Bytecode)
        if is.size > 0
            t = is[0].lastc 
            if t 
                tmp = t 
            else
                tmp = is[0]
            end
            (1...is.size).each do |i|
                tmp.nextc = is[i]
                last = is[i].lastc
                if last 
                    tmp = last
                else
                    tmp = is[i]
                end
            end
        else 
            raise CompilerError.new("Failed to link bytecode")
        end
    end

    @[AlwaysInline]
    protected def emit_store_l(name : String,forced = false)
        if @block_depth == 0 || forced
            iseq      = @ifactory.makeBCode(Code::STOREL_0)
            STstack.set(name)
        else
            index = STstack.fetch(name,@block_depth)
            if index >= 0
                case index
                    when 0
                        iseq = @ifactory.makeBCode(Code::STOREL_0)
                    when 1
                        iseq = @ifactory.makeBCode(Code::STOREL_1)
                    when 2
                        iseq = @ifactory.makeBCode(Code::STOREL_2)
                    else 
                        iseq = @ifactory.makeBCode(Code::STOREL)
                        iseq.value = index 
                end
            else
                iseq = @ifactory.makeBCode(Code::STOREL_0)
                STstack.set(name)
            end
        end 
        iseq.text = name
        return iseq
    end

    @[AlwaysInline]
    protected def emit_load_v(name : String)
        if @block_depth == 0
            is = @ifactory.makeBCode(Code::LOADV)
        else 
            index = STstack.fetch(name,@block_depth)
            if index >= 0
                case index
                    when 0
                        is = @ifactory.makeBCode(Code::LOADL_0)
                    when 1
                        is = @ifactory.makeBCode(Code::LOADL_1)
                    when 2
                        is = @ifactory.makeBCode(Code::LOADL_2)
                    else
                        is = @ifactory.makeBCode(Code::LOADL)
                        is.value = index 
                end
            else
                is = @ifactory.makeBCode(Code::LOADV)
            end 
        end 
        is.text = name 
        return is 
    end

    def compile(ast)
        if ast
            code       = compile_stmts(ast)
            link(code,HALT)
            return code
        end
        return Noop
    end

    protected def compile_program(ast : Node)
        last  = nil
        first = @ifactory.makeBCode(Code::FILENAME)
        first.text = get_node_file(ast)
        if ast
            branches = ast.getBranches
            branches.each do |b|
                bitecode = compile_stmts(b)
                if last
                    last.nextc = bitecode
                else
                    first.nextc = bitecode
                end
                if bitecode.lastc
                    last = bitecode.lastc
                else
                    last = bitecode
                end
            end
            if last
                set_last(first,last)
            end
            return first
        end
        return Noop
    end

    protected def compile_stmts(node : Node)
        case node.type
            when NodeType::PROGRAM
                return compile_program(node) 
            when NodeType::READS
                return compile_reads(node)
            when NodeType::PRINT, NodeType::PRINTL
                return compile_print(node)
            when NodeType::CLASS
                return compile_class(node)
            when NodeType::MODULE 
                return compile_module(node)
            when NodeType::VOID
                return compile_void(node)
            else 
                return compile_exp(node)
        end
    end

    protected def compile_reads(node : Node)
        line   =new_line(node)
        pself  = @ifactory.makeBCode(Code::PUSHSELF)
        pop_is = @ifactory.makeBCode(Code::POPOBJ)
        call   = make_call_is("reads",0)
        link(line,pself,call)
        set_last(line,call)
        return line
    end

    protected def compile_print(node : Node)
        line = new_line(node)
        last     = pushself
        callname = node.type == NodeType::PRINT ? "print" : "printl"
        args     = node.getBranches
        link(line,last)
        if args.size > 0
            args.each_with_index do |exp,i|
                callis   = make_call_is(callname,1)  
                exp_iseq = compile_exp(exp,false)
                link(last,exp_iseq,callis)
                if i < args.size - 1
                    pop_is = popobj
                    link(callis,pop_is)
                    last = pop_is
                else 
                    last = callis
                end
            end
        else
            value  = @ifactory.makeBCode(Code::PUSHN)
            callis = make_call_is(callname,1)
            link(last,value,callis)
            last = callis
        end
        set_last(line,last)
        return line
    end

    protected def compile_namespace(node : Node,complete = true)
        branches   = node.getBranches
        final      = branches.size - (complete ? 0 : 1)
        first      = @ifactory.makeBCode(Code::LOADC)
        first.text = unpack_name(branches.first)
        last       = first
        (1...final).each do |i|
            tmp      = @ifactory.makeBCode(Code::GETC)
            tmp.text = unpack_name(branches[i])
            link(last,tmp)
            last = tmp
        end
        set_last(first,last)
        return first
    end

    protected def compile_class(node : Node)
        STstack.push_table
        namespace   = node.getAttr(NKey::NAME).as(Node)
        parent      = node.getAttr(NKey::PARENT)
        body        = node.getBranches[0]
        full_name   = namespace.as(Node).getBranches
        line        = new_line(node)
        leave_is    = leave
        c_name      = @ifactory.makeBCode(Code::PUT_CLASS)
        if full_name.size == 1
            name        = full_name.last
            c_nspace    = pushself
            c_name.text = unpack_name(name)
        else
            c_nspace    = compile_namespace(namespace,false)
            name        = full_name.last
            c_name.text = unpack_name(name)
        end
        if parent
            c_parent = compile_namespace(parent.as(Node))  
        else 
            c_parent = pushn
        end
        c_body      = compile_body(body)
        link(c_body,leave_is)
        c_name.jump = c_body
        link(line,c_nspace,c_parent,c_name)
        set_last(line,c_name)
        STstack.pop_table
        return line
    end

    protected def compile_module(node : Node)
        STstack.push_table
        namespace = node.getAttr(NKey::NAME).as(Node)
        body      = node.getBranches.first
        full_name = namespace.getBranches
        line      = new_line(node)
        pop_is    = popobj
        leave_is  = leave
        c_name    = @ifactory.makeBCode(Code::PUT_MODULE)
        if full_name.size == 1
            name        = full_name.last
            c_nspace    = pushself
            c_name.text = unpack_name(name)
        else
            c_nspace    = compile_namespace(namespace,false)
            name        = full_name.last
            c_name.text = unpack_name(name)
        end 
        c_body = compile_body(body)
        link(c_body,leave_is)
        c_name.jump = c_body
        link(line,c_nspace,c_name)
        set_last(line,c_name)
        STstack.pop_table
        return line
    end

    protected def compile_void(node : Node)
        STstack.push_table
        name     = node.getAttr(NKey::NAME).as(Node)
        visib    = node.getAttr(NKey::VOID_VISIB)
        branches = node.getBranches
        args     = branches[0]
        arity    = args.getAttr(NKey::VOID_ARITY).as(Intnum)
        body     = branches[1]
        static   = false
        if name.type == NodeType::SELF
            voidName   = unpack_name(name.getBranches[0]).as(String)
            c_receiver = pushself
            static     = true
        else
            voidName = unpack_name(name).as(String)
            receiver = name.getAttr(NKey::RECEIVER)
            if receiver
                if receiver.as(Node).type == NodeType::NAMESPACE
                    c_receiver = compile_namespace(receiver.as(Node))
                    static   = true
                else
                    c_receiver      = @ifactory.makeBCode(Code::LOADC) 
                    c_receiver.text = unpack_name(receiver.as(Node))
                    static = true
                end
            else
                c_receiver = @ifactory.makeBCode(Code::PUSHSELF)
            end
        end
        ret_is = make_null_return
        file   = new_file(node)
        line   = new_line(node)
        pop_is = popobj
        b_noop = noop
        c_body = compile_body(body)
        c_args = compile_void_args(args)
        link(b_noop,file,c_body,ret_is)
        set_last(b_noop,ret_is)
        if {VoidVisib::PUBLIC,nil}.includes? visib
            if static 
                method = internal.lc_def_static_method(voidName,c_args,arity,b_noop)
            else
                method = internal.lc_def_method(voidName,c_args,arity,b_noop)
            end
        else 
            if static 
                method = internal.lc_def_static_method(voidName,c_args,arity,b_noop,visib.as(VoidVisib))
            else
                method = internal.lc_def_method(voidName,c_args,arity,b_noop,visib.as(VoidVisib))
            end
        end
        if static
            bind_is = @ifactory.makeBCode(Code::PUT_STATIC_METHOD)
        else
            bind_is = @ifactory.makeBCode(Code::PUT_INSTANCE_METHOD)
        end 
        bind_is.text   = voidName
        bind_is.method = method 
        link(line,c_receiver,bind_is,pop_is)
        set_last(line,pop_is)
        STstack.pop_table
        return line
    end

    protected def compile_void_args(node : Node)
        branches = node.getBranches
        args     = [] of VoidArgument
        return args if branches.size == 0
        branches.each do |branch|
            if branch.type == NodeType::ASSIGN
                name = unpack_name(branch.getBranches[0])
                opt  = compile_exp(branch)
                nxt  = @ifactory.makeBCode(Code::NEXT)
                link(opt,nxt)
                arg         = @ifactory.makeVoidArg(name,true) 
                arg.optcode = opt
                args << arg
            else
                name = unpack_name(branch)
                args << @ifactory.makeVoidArg(name) 
            end
        end
        return args
    end

    protected def compile_body(node : Node)
        branches = node.getBranches
        if branches.size == 0
            return noop
        else
            first = compile_stmts(branches.first)
            prev  = first
            (1...branches.size).each do |i|
                tmp = compile_stmts(branches[i])
                link(prev,tmp)
                prev = tmp 
            end
            set_last(first,prev)
            return first 
        end
    end

    protected def compile_assign(node : Node)
        branches = node.getBranches
        var      = branches[0]
        expr     = branches[1]
        c_expr   = compile_exp(expr,false)
        pop_is   = popobj
        if var.type != NodeType::METHOD_CALL
            name  = unpack_name(var)
            if var.type == NodeType::LOCAL_ID
                iseq = emit_store_l(name)
                link(c_expr,iseq)
                set_last(c_expr,iseq)
                return c_expr
            else 
                iseq   = pushself
                storeg = @ifactory.makeBCode(Code::STOREG)
                link(iseq,c_expr,storeg,pop_is)
                set_last(iseq,storeg)
                return iseq
            end
        else
            r_node     = var.getAttr(NKey::RECEIVER).as(Node)
            args       = var.getBranches[1]
            c_args     = compile_call_args(args)[0]
            link(c_args,c_expr)
            set_last(c_args,c_expr)
            c_receiver = compile_exp(r_node,false)
            c_call     = make_m_call_is("[]=",args.getBranches.size + 1)
            link(c_receiver,c_args,c_call)
            set_last(c_receiver,c_call)
            return c_receiver
        end 
    end

    protected def compile_call_args(node : Node)
        branches = node.getBranches
        block    = node.getAttr(NKey::BLOCK)
        if block
            c_block = compile_block(block.as(Node))
        else 
            c_block = nil
        end
        return {noop,c_block} if branches.size == 0
        first = compile_exp(branches[0],false)
        f     = first
        (1...branches.size).each do |i|
            tmp = compile_exp(branches[i],false)
            link(f,tmp)
            f   = tmp
        end
        set_last(first,f) unless first == f
        return {first,c_block}
    end

    protected def compile_block_args(node : Node)
        arg_list = node.getBranches
        previous = nil
        follow_v = [] of VoidArgument
        arg_list.each do |arg|
            if arg.type == NodeType::ASSIGN
                name = unpack_name(arg.getBranches[0])
                opt  = compile_exp(arg)
                nxt  = @ifactory.makeBCode(Code::NEXT)
                link(opt,nxt)
                arg         = @ifactory.makeVoidArg(name,true)
                arg.optcode = opt 
                follow_v << arg
            else 
                name        = unpack_name(arg)
                p_null      = pushn
                storel      = emit_store_l(name,true)
                pop_is      = popobj
                nxt         = @ifactory.makeBCode(Code::NEXT)
                link(p_null,storel,pop_is,nxt)
                arg         = @ifactory.makeVoidArg(name,true)
                arg.optcode = p_null 
                follow_v << arg
            end
            STstack.set(name)
        end 
        return follow_v
    end

    protected def compile_block(node : Node)
        @block_depth += 1
        STstack.push_table
        argv   = node.as(Node).getAttr(NKey::BLOCK_ARG)
        c_args = compile_block_args(argv.as(Node)) if argv
        c_noop = noop
        c_body = compile_body(node)
        ret_is = make_null_next
        file   = new_file(node)
        link(c_noop,file,c_body,ret_is)
        block         = LcBlock.new(c_noop)
        if c_args
            block.args    = c_args
        end 
        STstack.pop_table
        @block_depth -= 1
        return block
    end

    protected def compile_exp(node : Node,with_pop = true)
        line = new_line(node)
        case node.type 
            when NodeType::LOCAL_ID
                name = unpack_name(node)
                is   = emit_load_v(name)
            when NodeType::GLOBAL_ID
                is  = pushself
                var = @ifactory.makeBCode(Code::LOADG)
                link(is,var)
                set_last(is,var)
            when NodeType::ASSIGN
                is = compile_assign(node)
            when NodeType::INT 
                is       = @ifactory.makeBCode(Code::PUSHINT)
                is.value = node.getAttr(NKey::VALUE).as(Intnum)
            when NodeType::FLOAT
                is       = @ifactory.makeBCode(Code::PUSHFLO)
                is.value = node.getAttr(NKey::VALUE).as(Floatnum)
            when NodeType::CALL
                is = compile_call(node)
            when NodeType::METHOD_CALL
                is = compile_m_call(node)
            when NodeType::TRUE
                is = @ifactory.makeBCode(Code::PUSHT)
            when NodeType::FALSE
                is = @ifactory.makeBCode(Code::PUSHF)
            when NodeType::NULL
                is = @ifactory.makeBCode(Code::PUSHN)
            when NodeType::STRING
                is      = @ifactory.makeBCode(Code::PUSHSTR)
                is.text = node.getAttr(NKey::VALUE).as(String)
            when NodeType::NAMESPACE
                is = compile_namespace(node)
            when NodeType::RETURN
                is = compile_return(node)
            when NodeType::ARRAY
                is = compile_array(node)
            when NodeType::IRANGE, NodeType::ERANGE
                is = compile_range(node)
            when NodeType::MATRIX
                is = compile_matrix(node)
            when NodeType::READS
                is = compile_reads(node)
            when NodeType::PRINT, NodeType::PRINTL
                is = compile_print(node)
            when NodeType::NEW 
                is = compile_new(node)
            when NodeType::SELF
                is = pushself
            when NodeType::YIELD
                id = compile_yield(node)
            else 
                is = noop
        end
        if with_pop
            pop_is = popobj
            link(line,is,pop_is)
            set_last(line,pop_is)
        else 
            return is
        end 
        return line
    end

    protected def compile_call(node : Node)
        branches = node.getBranches
        name     = unpack_name(branches[0])
        args     = branches[1]
        c_args   = compile_call_args(args)
        c_argl   = c_args[0]
        block    = c_args[1]
        pself    = pushself
        if block 
            call_is = make_call_with_block_is(name,args.getBranches.size,block)
        else 
            call_is = make_call_is(name,args.getBranches.size)
        end
        link(pself,c_argl,call_is)
        set_last(pself,call_is)
        return pself
    end

    protected def compile_m_call(node : Node)
        receiver = node.getAttr(NKey::RECEIVER).as(Node)
        branches = node.getBranches
        name     = branches[0]
        args     = branches[1]

        callname   = unpack_name(name)
        c_receiver = compile_exp(receiver,false)
        c_args     = compile_call_args(args)
        c_argl     = c_args[0]
        block      = c_args[1]
        if block
            call_is = make_m_call_with_block_is(callname,args.getBranches.size,block)
        else 
            call_is = make_m_call_is(callname,args.getBranches.size)
        end
        link(c_receiver,c_argl,call_is)
        set_last(c_receiver,call_is)
        return c_receiver
    end

    protected def compile_return(node : Node)
        exp   = node.getBranches[0]
        c_exp = compile_exp(exp,false)
        ret   = @ifactory.makeBCode(Code::RETURN)
        link(c_exp,ret)
        set_last(c_exp,ret)
        return c_exp
    end

    protected def compile_array(node : Node)
        branches     = node.getBranches
        ary_is       = @ifactory.makeBCode(Code::ARY_NEW)
        ary_is.value = branches.size
        if branches.size > 0
            first    = compile_exp(branches.last,false)
            tmp      = first 
            i        = branches.size - 2
            while i >= 0
                tmp2 = compile_exp(branches[i],false)
                link(tmp,tmp2)
                tmp = tmp2
                i  -= 1
            end
            link(tmp,ary_is)
            set_last(first,ary_is)
            return first
        else 
            return ary_is
        end
    end

    protected def compile_range(node : Node)
        branches = node.getBranches
        left     = compile_exp(branches[0],false)
        right    = compile_exp(branches[1],false)
        if node.type == NodeType::IRANGE
            range_is = @ifactory.makeBCode(Code::IRANGE_NEW)
        else
            range_is = @ifactory.makeBCode(Code::ERANGE_NEW)
        end 
        link(left,right,range_is)
        set_last(left,range_is)
        return left
    end

    protected def compile_matrix(node : Node)
        branches = node.getBranches
        rws      = branches.size 
        cls      = (branches[0]? ? branches[0].getBranches.size : 0)
        mx_is    = @ifactory.makeBCode(Code::MX_NEW)
        mx_is.value = rws 
        mx_is.opt_v = cls
        if rws > 0 && cls > 0
            first = compile_matrix_row(branches.last) 
            tmp   = first 
            i     = rws  -2
            while i >= 0
                tmp2 = compile_matrix_row(branches[i])
                link(tmp,tmp2)
                tmp = tmp2 
                i  -= 1
            end 
            link(tmp,mx_is)
            set_last(first,mx_is)
            return first
        end
        return mx_is
    end

    protected def compile_matrix_row(node : Node)
        branches = node.getBranches
        first    = compile_exp(branches.last,false)
        tmp      = first
        i        = branches.size - 2
        while i >= 0
            tmp2 = compile_exp(branches[i],false)
            link(tmp,tmp2)
            tmp = tmp2 
            i  -= 1
        end 
        set_last(first,tmp)
        return first
    end

    protected def compile_new(node : Node)
        branches  = node.getBranches
        namespace = branches[0]
        args      = branches[1]
        c_nspace  = compile_namespace(namespace)
        c_args    = compile_call_args(args)                # Fix call_with_block
        n_obj     = @ifactory.makeBCode(Code::NEW_OBJ)
        c_init    = @ifactory.makeBCode(Code::OPT_CALL_INIT)
        p_dup     = @ifactory.makeBCode(Code::PUSHDUP)
        p_obj     = popobj

        c_init.block   = c_args[1]
        c_init.argc = args.getBranches.size
        link(c_nspace,n_obj,p_dup,c_args[0],c_init,p_obj)
        set_last(c_nspace,p_obj)
        return c_nspace
    end

    protected def compile_yield(node : Node)
        c_args  = compile_call_args(node.getBranches[0])
        c_yield = @ifactory.makeBCode(Code::YIELD)
        link(c_args,c_yield)
        set_last(c_args,c_yield)
        return c_args
    end

    @[AlwaysInline]
    private def get_node_line(node : Node)
        line = node.getAttr(NKey::LINE) 
        node = node.parent
        while (!line) && node
            line = node.getAttr(NKey::LINE)
            node = node.parent
        end 
        line ||= 0
        return line.as(Intnum)
    end

    @[AlwaysInline]
    private def get_node_file(node : Node)
        filename = node.getAttr(NKey::FILENAME)
        node = node.parent
        while !filename && node
            filename = node.getAttr(NKey::FILENAME)
            node = node.parent
        end 
        return filename.as(String)
    end

    @[AlwaysInline]
    private def make_call_is(name : String, argc : Intnum)
        call      = @ifactory.makeBCode(Code::CALL)
        call.text = name
        call.argc = argc 
        return call
    end

    @[AlwaysInline]
    private def make_m_call_is(name : String, argc : Intnum)
        call      = @ifactory.makeBCode(Code::M_CALL)
        call.text = name
        call.argc = argc 
        return call
    end

    private def make_call_with_block_is(name : String,argc : Intnum, block : LcBlock?)
        call       = @ifactory.makeBCode(Code::CALL_WITH_BLOCK)
        call.text  = name
        call.argc  = argc 
        call.block = block
        return call
    end

    private def make_m_call_with_block_is(name : String,argc : Intnum, block : LcBlock?)
        call       = @ifactory.makeBCode(Code::M_CALL_WITH_BLOCK)
        call.text  = name
        call.argc  = argc 
        call.block = block
        return call
    end

    private def make_null_return
        null = pushn
        ret  = @ifactory.makeBCode(Code::RETURN)
        link(null,ret)
        set_last(null,ret)
        return null
    end

    private def make_null_next
        null = pushn
        ret  = @ifactory.makeBCode(Code::B_NEXT)
        link(null,ret)
        set_last(null,ret)
        return null
    end

    @[AlwaysInline]
    private def new_line(node : Node)
        line = @ifactory.makeBCode(Code::LINE)
        set_line(line,get_node_line(node))
        return line
    end

    private def new_file(node : Node)
        file = @ifactory.makeBCode(Code::FILENAME)
        file.text = get_node_file(node)
        return file
    end

    @[AlwaysInline]
    private def set_line(code : Bytecode,line : Intnum)
        code.line = line
    end

end