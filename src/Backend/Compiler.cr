
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

require "./Symbol_table"

class LinCAS::Compiler

    private class CompilerError < ::Exception
    end

    
    HALT       = Bytecode.new(Code::HALT)
    Noop       = Bytecode.new(Code::NOOP)
    NEXTB      = Bytecode.new(Code::NEXTB)
    STstack    = Symbol_Table_Stack.new
    SUM_ID     = "+"
    SUB_ID     = "-"
    PROD_ID    = "*"
    IDIV_ID    = "\\"
    FDIV_ID    = "/"
    POW_ID     = "**"
    MOD_ID     = "%"
    EQ_ID      = "=="
    GR_ID      = ">"
    SM_ID      = "<"
    GE_ID      = ">="
    SE_ID      = "<="
    NE_ID      = "!="
    NOT_ID     = "!"
    AND_ID     = "&&"
    OR_ID      = "||"
    APPEND_ID  = "<<"
    UMINUS_ID  = "-@"
    INCLUDE_ID = "include"

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
        @symbolic    = false
    end

    macro compile_binary_op(node,type)
        nodes  = {{node}}.getBranches
        exp1   = nodes[0]
        exp2   = nodes[1]
        c_exp  = compile_exp(exp1,false)
        c_exp2 = compile_exp(exp2,false)
        c_call = make_m_call_is({{type}},1)
        link(c_exp,c_exp2,c_call)
        set_last(c_exp,c_call)
        return c_exp
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
                tmp.nextc  = is[i]
                is[i].prev = tmp 
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

    def compile(ast,end_code = Code::HALT)
        if ast
            code    = compile_stmts(ast)
            e_code  = @ifactory.makeBCode(end_code)   
            link(code,e_code)
            return code
        end
        return Noop
    end

    protected def compile_program(ast : Node)
        last  = nil
        first = @ifactory.makeBCode(Code::FILENAME)
        first.text = get_node_file(ast)
        leave_c    = @ifactory.makeBCode(Code::LEAVE_C)
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
            link(first,leave_c)
            set_last(first,leave_c)
            return first
        end
        return Noop
    end

    protected def compile_stmts(node : Node)
        case node.type
            when NodeType::PROGRAM
                return compile_program(node) 
            when NodeType::CLASS
                return compile_class(node)
            when NodeType::MODULE 
                return compile_module(node)
            when NodeType::FUNC
                return compile_func(node)
            when NodeType::IF 
                return compile_if(node)
            when NodeType::WHILE
                return compile_while(node)
            when NodeType::UNTIL
                return compile_until(node)
            when NodeType::BODY
                return compile_for(node)
            when NodeType::SELECT
                return compile_slect(node)
            when NodeType::TRY 
                return compile_try(node)
            when NodeType::REQUIRE
                return compile_require(node)
            when NodeType::IMPORT
                return compile_import(node)
            else 
                return compile_exp(node)
        end
    end

    protected def compile_reads(node : Node)
        pself  = @ifactory.makeBCode(Code::PUSHSELF)
        call   = make_call_is("reads",0)
        link(pself,call)
        set_last(pself,call)
        return pself
    end

    protected def compile_print(node : Node)
        beg      = true
        first    = pushself
        last     = first 
        callname = node.type == NodeType::PRINT ? "print" : "printl"
        args     = node.getBranches
        if args.size > 0
            args.each_with_index do |exp,i|
                callis   = make_call_is(callname,1)  
                exp_iseq = compile_exp(exp,false)
                link(last,exp_iseq,callis)
                if i < args.size - 1
                    pop_is = popobj
                    link(last,exp_iseq,callis,pop_is) if beg 
                    if !beg
                        p_self = pushself
                        link(last,p_self,exp_iseq,callis,pop_is)  
                    end
                    beg = false if beg
                    last = pop_is
                else 
                    if beg 
                        link(last,exp_iseq,callis)
                    else
                        p_self = pushself
                        link(last,p_self,exp_iseq,callis)
                    end
                    last = callis
                end
                link(last)
            end
            
        else
            value  = @ifactory.makeBCode(Code::PUSHN)
            callis = make_call_is(callname,1)
            link(last,value,callis)
            last = callis
        end
        set_last(first,last)
        return first
    end

    protected def compile_namespace(node : Node,complete = true)
        branches    = node.getBranches
        final       = branches.size - (complete ? 0 : 1)
        first       = pushself
        load_c      = @ifactory.makeBCode(Code::LOADC)
        load_c.text = unpack_name(branches.first)
        last        = load_c
        (1...final).each do |i|
            tmp      = @ifactory.makeBCode(Code::GETC)
            tmp.text = unpack_name(branches[i])
            link(last,tmp)
            last = tmp
        end
        link(first,load_c)
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

    protected def compile_func(node : Node)
        STstack.push_table
        name     = node.getAttr(NKey::NAME).as(Node)
        visib    = node.getAttr(NKey::FUNC_VISIB)
        branches = node.getBranches
        args     = branches[0]
        arity    = args.getAttr(NKey::FUNC_ARITY).as(Intnum)
        body     = branches[1]
        static   = false
        if name.type == NodeType::SELF
            funcName   = unpack_name(name.getBranches[0]).as(String)
            c_receiver = pushself
            static     = true
        else
            funcName = unpack_name(name).as(String)
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
        c_args = compile_func_args(args)
        c_body = compile_body(body)
        link(b_noop,file,c_body,ret_is)
        set_last(b_noop,ret_is)
        if {FuncVisib::PUBLIC,nil}.includes? visib
            if static 
                method = internal.lc_def_static_method(funcName,c_args,arity,b_noop)
            else
                method = internal.lc_def_method(funcName,c_args,arity,b_noop)
            end
        else 
            if static 
                method = internal.lc_def_static_method(funcName,c_args,arity,b_noop,visib.as(FuncVisib))
            else
                method = internal.lc_def_method(funcName,c_args,arity,b_noop,visib.as(FuncVisib))
            end
        end
        if static
            bind_is = @ifactory.makeBCode(Code::PUT_STATIC_METHOD)
        else
            bind_is = @ifactory.makeBCode(Code::PUT_INSTANCE_METHOD)
        end 
        bind_is.text   = funcName
        bind_is.method = method 
        link(line,c_receiver,bind_is,pop_is)
        set_last(line,pop_is)
        STstack.pop_table
        return line
    end

    protected def compile_func_args(node : Node)
        branches = node.getBranches
        args     = [] of FuncArgument
        return args if branches.size == 0
        branches.each do |branch|
            if branch.type == NodeType::ASSIGN
                name = unpack_name(branch.getBranches[0])
                opt  = compile_exp(branch)
                nxt  = @ifactory.makeBCode(Code::QUIT)
                link(opt,nxt)
                arg         = @ifactory.makeFuncArg(name,true) 
                arg.optcode = opt
                args << arg
            else
                name = unpack_name(branch)
                args << @ifactory.makeFuncArg(name) 
            end
            STstack.set(name)
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
                storeg.text = name
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
        follow_v = [] of FuncArgument
        arg_list.each do |arg|
            if arg.type == NodeType::ASSIGN
                name = unpack_name(arg.getBranches[0])
                opt  = compile_exp(arg)
                nxt  = @ifactory.makeBCode(Code::QUIT)
                link(opt,nxt)
                arg         = @ifactory.makeFuncArg(name,true)
                arg.optcode = opt 
                follow_v << arg
            else 
                name        = unpack_name(arg)
                p_null      = pushn
                storel      = emit_store_l(name,true)
                pop_is      = popobj
                nxt         = @ifactory.makeBCode(Code::NEXT)
                link(p_null,storel,pop_is,nxt)
                arg         = @ifactory.makeFuncArg(name,true)
                arg.optcode = p_null 
                follow_v << arg
            end
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
                if @symbolic
                    is = compile_symbolic_atom(node)
                else
                    name = unpack_name(node)
                    is   = emit_load_v(name)
                end
            when NodeType::GLOBAL_ID
                is  = pushself
                var = @ifactory.makeBCode(Code::LOADG)
                var.text = unpack_name(node)
                link(is,var)
                set_last(is,var)
            when NodeType::CONST_ID
                is          = pushself
                load_c      = @ifactory.makeBCode(Code::LOADC)
                load_c.text = unpack_name(node)
                link(is,load_c)
                set_last(is,load_c)
            when NodeType::ASSIGN
                is = compile_assign(node)
            when NodeType::INT 
                if @symbolic
                    is = compile_symbolic_atom(node)
                else
                    is       = @ifactory.makeBCode(Code::PUSHINT)
                    is.value = node.getAttr(NKey::VALUE).as(Intnum)
                end
            when NodeType::FLOAT
                if @symbolic
                    is = compile_symbolic_atom(node)
                else
                    is       = @ifactory.makeBCode(Code::PUSHFLO)
                    is.value = node.getAttr(NKey::VALUE).as(Floatnum)
                end
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
            when NodeType::NEXT 
                is = compile_next(node)
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
                is = compile_yield(node)
            when NodeType::RAISE
                is = compile_raise(node)
            when NodeType::INCLUDE
                is = compile_include(node)
            when NodeType::CONST
                is = compile_const(node)
            when NodeType::ANS 
                is = @ifactory.makeBCode(Code::PUSHANS)
            when NodeType::HASH
                is = compile_hash(node)
            when NodeType::SYMBOLIC
                is = compile_symbolic(node)
            when NodeType::SYMBOL 
                is = @ifactory.makeBCode(Code::SYMBOL_NEW)
                is.text = unpack_name(node)
            else 
                is = compile_op(node)
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

    protected def compile_op(node : Node)
        case node.type 
            when NodeType::SUM 
                compile_binary_op(node,SUM_ID)
            when NodeType::SUB
                compile_binary_op(node,SUB_ID)
            when NodeType::MUL 
                compile_binary_op(node,PROD_ID)
            when NodeType::FDIV
                compile_binary_op(node,FDIV_ID)
            when NodeType::IDIV 
                compile_binary_op(node,IDIV_ID)
            when NodeType::POWER
                compile_binary_op(node,POW_ID)
            when NodeType::MOD 
                compile_binary_op(node,MOD_ID)
            when NodeType::AND 
                compile_binary_op(node,AND_ID)
            when NodeType::OR 
                compile_binary_op(node,OR_ID)
            when NodeType::GE 
                compile_binary_op(node,GE_ID)
            when NodeType::SE 
                compile_binary_op(node,SE_ID)
            when NodeType::GR 
                compile_binary_op(node,GR_ID)
            when NodeType::SM 
                compile_binary_op(node,SM_ID)
            when NodeType::EQ 
                compile_binary_op(node,EQ_ID)
            when NodeType::APPEND 
                compile_binary_op(node,APPEND_ID)
            when NodeType::NE 
                compile_binary_op(node,NE_ID)
            when NodeType::NOT 
                exp   = node.getBranches[0]
                c_exp = compile_exp(exp,false)
                call  = make_m_call_is(NOT_ID,0)
                link(c_exp,call)
                set_last(c_exp,call)
                return c_exp 
            when NodeType::INVERT
                exp   = node.getBranches[0]
                c_exp = compile_exp(exp,false)
                call  = make_m_call_is(UMINUS_ID,0)
                link(c_exp,call)
                set_last(c_exp,call)
                return c_exp
            else 
                raise CompilerError.new("Compiler did not handle '#{node.type}' node")
        end
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

    protected def compile_next(node : Node)
        exp   = node.getBranches[0]
        c_exp = compile_exp(exp,false)
        ret   = @ifactory.makeBCode(Code::NEXT)
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
        c_args    = compile_call_args(args)                
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

    protected def compile_yield(node : Node) : Bytecode
        args         = node.getBranches[0]?
        c_yield      = @ifactory.makeBCode(Code::YIELD)
        if args 
            c_args       = compile_call_args(args)[0]
            c_yield.argc = args.getBranches.size
            link(c_args,c_yield)
            set_last(c_args,c_yield)
            return c_args
        end
        c_yield.argc = 0
        return c_yield
    end

    protected def compile_if(node : Node)
        branches  = node.getBranches
        condition = branches[0]
        then_b    = branches[1]
        else_b    = branches[2]?
        line      = new_line(condition)
        c_condition = compile_exp(condition,false)
        c_then_b    = compile_body(then_b)
        if else_b 
            if else_b.type == NodeType::IF 
                c_else_b = compile_if(else_b)
            else
                c_else_b = compile_body(else_b)
            end
        else 
            c_else_b = nil 
        end
        jump        = @ifactory.makeBCode(Code::JUMPF)
        noop_is     = noop
        if c_else_b
            u_jump      = @ifactory.makeBCode(Code::JUMP)
            u_jump.jump = noop_is
            jump.jump   = u_jump
            link(line,c_condition,jump,c_then_b,u_jump,c_else_b,noop_is)
        else 
            jump.jump = noop_is
            link(line,c_condition,jump,c_then_b,noop_is)
        end 
        set_last(line,noop_is) 
        return line
    end

    protected def compile_while(node : Node)
        branches  = node.getBranches
        condition = branches[0]
        body      = branches[1]
        c_body    = compile_body(body)
        line      = new_line(condition)
        c_condition = compile_exp(condition,false)
        jumpf     = @ifactory.makeBCode(Code::JUMPF)
        jump      = @ifactory.makeBCode(Code::JUMP)
        noop_is   = noop 
        jumpf.jump = noop_is
        jump.jump  = line 
        link(line,c_condition,jumpf,c_body,jump,noop_is)
        set_last(line,noop_is)
        return line
    end

    protected def compile_until(node : Node)
        branches  = node.getBranches
        body      = branches[0]
        condition = branches[1]
        c_body    = compile_body(body)
        c_condition = compile_exp(condition,false)
        line        = new_line(node)
        jumpf       = @ifactory.makeBCode(Code::JUMPF)
        jumpf.jump  = c_body
        link(c_body,line,c_condition,jumpf)
        set_last(c_body,jumpf)
        return c_body 
    end

    protected def compile_for(node : Node)
        branches = node.getBranches
        assign   = branches[0]
        w_loop   = branches[1]
        loop_b   = w_loop.getBranches
        condition = loop_b[0]
        body     = loop_b[1]
        c_assign = compile_assign(assign)
        c_body   = compile_body(body)
        c_condit = compile_for_condition(condition)
        noop_is  = noop 
        jumpf    = @ifactory.makeBCode(Code::JUMPF)
        jump     = @ifactory.makeBCode(Code::JUMP)
        jumpf.jump = noop_is
        jump.jump  = c_condit
        link(c_assign,c_condit,jumpf,c_body,jump,noop_is)
        set_last(c_assign,noop_is)
        return c_assign
    end

    protected def compile_for_condition(node : Node)
        c_brnchs = node.getBranches
        line     = new_line(node)
        left     = c_brnchs[0]
        right    = c_brnchs[1]
        c_left   = compile_exp(left,false)
        c_right  = compile_exp(right,false)
        if node.type == NodeType::SE 
            call = make_m_call_is(SE_ID,1)
        else 
            call = make_m_call_is(GE_ID,1)
        end
        link(line,c_left,c_right,call)
        set_last(line,call)
        return line
    end

    protected def compile_raise(node : Node)
        exp    = node.getBranches[0]
        p_self = pushself
        c_exp  = compile_exp(exp,false)
        call   = make_call_is("raise",1)
        link(p_self,c_exp,call)
        set_last(p_self,call)
        return p_self
    end

    protected def compile_include(node : Node)
        namespace = node.getBranches[0]
        c_nspace  = compile_namespace(namespace)
        pself     = pushself
        call      = make_call_is(INCLUDE_ID,1)
        link(pself,c_nspace,call)
        set_last(pself,call)
        return pself
    end

    protected def compile_slect(node : Node)
        branches  = node.getBranches
        condition = branches[0]
        c_opts    = compile_opts(branches)
        c_condition = compile_exp(condition,false)
        pop_is      = popobj
        link(c_condition,c_opts,pop_is)
        set_last(c_condition,pop_is)
        return c_condition
    end

    protected def compile_opts(branches : Array(Node))
        len = branches.size
        if len > 2
            array    = StaticArray(Bytecode?,2).new(nil)
            array[0] = noop
            i     = 2
            opt   = branches[1]
            c_opt = compile_opt(opt,array.to_unsafe)
            tmp   = c_opt
            while i < len 
                opt  = branches[i]
                tmp2 = compile_opt(opt,array.to_unsafe)
                link(tmp,tmp2)
                tmp = tmp2 
                i += 1
            end 
            set_last(c_opt,tmp)
            _end_op = array[0].as(Bytecode)
            if else_c = array[1]
                link(c_opt,else_c,_end_op)
            else 
                link(c_opt,_end_op)
            end 
            set_last(c_opt,_end_op)
            return c_opt
        else 
            return noop 
        end
    end

    protected def compile_opt(node : Node,array)
        if node.type == NodeType::CASE
            return compile_case(node,array)
        else 
            _else = compile_body(node.getBranches[0])
            array[1] = _else
        end
        noop
    end

    protected def compile_case(node : Node,array)
        end_op   = array[0].as(Bytecode)
        branches = node.getBranches
        conditions = branches[0]
        body       = branches[1]
        c_body     = compile_body(body)
        jump       = @ifactory.makeBCode(Code::JUMP)
        jump.jump  = end_op 
        noop_is    = noop
        c_condts   = compile_opt_conditions(conditions,c_body)
        jump2      = @ifactory.makeBCode(Code::JUMP)
        jump2.jump = noop_is
        link(c_condts,jump2,c_body,jump,noop_is)
        set_last(c_condts,noop_is)
        return c_condts
    end

    protected def compile_opt_conditions(node : Node,body : Bytecode)
        branches = node.getBranches
        first    = branches[0]
        c_exp    = compile_exp(first,false)
        first    = emit_case_is(c_exp,body)
        tmp      = first
        count    = branches.size 
        i        = 1
        while i < count 
            c_exp = compile_exp(branches[i],false)
            tmp2  = emit_case_is(c_exp,body)
            link(tmp,tmp2)
            tmp = tmp2 
            i += 1
        end
        set_last(first,tmp)
        return first
    end

    protected def emit_case_is(condition : Bytecode,body : Bytecode)
        p_dup    = @ifactory.makeBCode(Code::PUSHDUP)
        eq_cmp   = @ifactory.makeBCode(Code::EQ_CMP)
        jumpt    = @ifactory.makeBCode(Code::JUMPT)
        jumpt.jump = body
        link(p_dup,condition,eq_cmp,jumpt)
        set_last(p_dup,jumpt)
        return p_dup
    end

    protected def compile_try(node : Node)
        branches = node.getBranches
        try      = branches[0]
        catch    = branches[1]?
        c_body   = compile_body(try)
        set_ct   = @ifactory.makeBCode(Code::SET_C_T)
        clear_ct = @ifactory.makeBCode(Code::CLEAR_C_T)
        noop_is  = noop
        if catch 
            c_catch = compile_catch(catch)
            c_table = new_catch_t(c_catch)
        else 
            c_catch = {noop,nil}
            c_table = new_catch_t(c_catch)
        end 
        link(set_ct,c_body,clear_ct,noop_is)
        link(c_catch[0],clear_ct)
        set_last(set_ct,noop_is)
        set_ct.catch_t = c_table
        return set_ct
    end

    protected def compile_catch(node : Node)
        branches = node.getBranches
        if branches.size > 1
            id   = unpack_name(branches[0])
            body = branches[1]
        else 
            id   = nil
            body = branches[0]
        end 
        c_body = compile_body(body)
        return {c_body,id}
    end

    protected def compile_const(node : Node)
        branch       = node.getBranches[0]
        branches     = branch.getBranches
        c_exp        = compile_exp(branches[1],false)
        p_self       = pushself
        store_c      = @ifactory.makeBCode(Code::STOREC)
        store_c.text = unpack_name(branches[0])
        link(p_self,c_exp,store_c)
        set_last(p_self,store_c)
        return p_self
    end

    protected def compile_require(node : Node)
        branch  = node.getBranches[0]
        p_self  = pushself
        c_exp   = compile_exp(branch,false)
        call_is = make_call_is(unpack_name(node),1)
        pop_is  = popobj
        link(p_self,c_exp,call_is,pop_is)
        set_last(p_self,pop_is)
        return p_self
    end

    protected def compile_import(node : Node)
        branch  = node.getBranches[0]
        p_self  = pushself
        c_exp   = compile_exp(branch,false)
        call_is = make_call_is("import",1)
        pop_is  = popobj
        link(p_self,c_exp,call_is,pop_is)
        set_last(p_self,pop_is)
        return p_self
    end

    protected def compile_hash(node : Node)
        branches    = node.getBranches
        n_hash      = @ifactory.makeBCode(Code::HASH_NEW)
        n_hash.argc = branches.size
        if branches.size > 0
            first       = compile_hash_atom(branches.last)
            tmp         = first
            (branches.size - 1).downto 0 do |i|
                c_atom = compile_hash_atom(branches[i])
                link(tmp,c_atom)
                tmp = c_atom
            end
            set_last(first,tmp)
            link(first,n_hash)
            set_last(first,n_hash)
            return first
        end
        return n_hash
    end

    protected def compile_hash_atom(node : Node)
        branches = node.getBranches
        line     = new_line(node)
        c_key    = compile_exp(branches[0],false)
        c_val    = compile_exp(branches[1],false)
        link(line,c_key,c_val)
        set_last(line,c_val)
        return line
    end

    protected def compile_symbolic(node : Node)
        @symbolic = true
        branch = node.getBranches[0]
        is    = compile_sym_tree(branch)
        new_f = @ifactory.makeBCode(Code::NEW_FUNC)
        link(is,new_f)
        set_last(is,new_f)
        @symbolic = false
        return is
    end

    macro compile_sym_op(code,node)
        branches = {{node}}.getBranches
        left  = compile_sym_tree(branches[0])
        right = compile_sym_tree(branches[1])
        op    = @ifactory.makeBCode(Code::{{code.id}})
        link(left,right,op)
        set_last(left,op) 
        return left 
    end

    protected def compile_sym_tree(node : Node)
        {% begin %}

        case node.type 
            when NodeType::LOCAL_ID
                tmp = @ifactory.makeBCode(Code::NEW_SVAR) 
                tmp.text = unpack_name(node)
                return tmp
            when NodeType::INT
                tmp = @ifactory.makeBCode(Code::NEW_SNUM)
                tmp.value = node.getAttr(NKey::VALUE).as(Intnum)
                return tmp
            {% for block in { {"SUM","S_SUM"},{"SUB","S_SUB"},{"MUL","S_PROD"},
                              {"FDIV","S_DIV"},{"IDIV","S_DIV"},{"POWER","S_POW"} } %}

            when NodeType::{{block[0].id}}
                compile_sym_op({{block[1]}},node)

            {% end %}
            when NodeType::INVERT
                op = compile_exp(node.getBranches[0],false)
                is = @ifactory.makeBCode(Code::S_INVERT)
                link(op,is)
                set_last(op,is)
                return is 
            else
                return compile_exp(node,false)
        end

        {% end %}
    end
    
    protected def compile_symbolic_atom(node : Node)
        is    = compile_sym_tree(node)
        new_f = @ifactory.makeBCode(Code::NEW_FUNC)
        link(is,new_f)
        set_last(is,new_f)
        return is
    end

    @[AlwaysInline]
    protected def new_catch_t(c_catch : Tuple(Bytecode,(String | Nil)))
        return CatchTable.new(*c_catch)
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
        null = @ifactory.makeBCode(Code::PUSHANS)
        ret  = @ifactory.makeBCode(Code::RETURN)
        link(null,ret)
        set_last(null,ret)
        return null
    end

    private def make_null_next
        null = @ifactory.makeBCode(Code::PUSHANS)
        ret  = @ifactory.makeBCode(Code::NEXT)
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