
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

class LinCAS::Disassembler

    macro print_filename(filename)
        print "<file>: ", {{filename}}, "\n"
    end

    macro print_line(line)
        print "<line>: ",{{line}},"\n"
    end

    def initialize
    end

    def disassemble(code : Bytecode)
        print_iseq(code)
    end

    protected def print_iseq(iseq : Bytecode)
        loop do
            print_is(iseq)
            iseq = iseq.nextc
            break unless iseq 
        end
    end

    protected def print_is(iseq : Bytecode)
        code = iseq.code
        case code
            when Code::CALL, Code::M_CALL, Code::YIELD
                print code, ' ', '"', iseq.text, '"', ' ', iseq.argc, '\n'
            when Code::PRINT, Code::PRINTL, Code::PUSHSELF,Code::POPOBJ,Code::PUSHN,
                 Code::HALT,Code::LEAVE,Code::RETURN, Code::IRANGE_NEW,Code::ERANGE_NEW,
                 Code::NEW_OBJ, Code::PUSHDUP, Code::NEXT, Code::PUSHT, Code::PUSHF, Code::EQ_CMP,
                 Code::CLEAR_C_T, Code::LEAVE_C, Code::NEW_FUNC, Code::S_SUM, Code::S_SUB,
                 Code::S_PROD, Code::S_DIV, Code::S_POW, Code::QUIT, Code::PUSHANS, Code::S_INVERT
                puts code
            when Code::LINE
                print_line(iseq.line)
            when Code::FILENAME
                print_filename(iseq.text)
            when Code::STRING_NEW, Code::LOADC, Code::GETC,
                 Code::STOREL_0, Code::STOREL_1, Code::STOREL_2, Code::STOREG, Code::STOREC, 
                 Code::LOADV, Code::LOADL_0, Code::LOADL_1,Code::LOADL_2, Code::LOADG,
                 Code::NEW_SVAR
                print code, ' ', '"', iseq.text, '"',' ', '\n'
            when Code::STOREL, Code::LOADL 
                print code, ' ', '"', iseq.text, '"',',', iseq.value,'\n'
            when Code::PUT_INSTANCE_METHOD, Code::PUT_STATIC_METHOD
                print code, ' ', '"', iseq.text, '"',' ', '\n'
                print_method_is(iseq)
            when Code::PUSHINT, Code::PUSHFLO, Code::ARY_NEW, Code::HASH_NEW, Code::NEW_SNUM
                print code, ' ', iseq.value, '\n'
            when Code::CALL_WITH_BLOCK, Code::M_CALL_WITH_BLOCK
                print code, ' ', '"', iseq.text, '"', ' ', iseq.argc, '\n'
                print_block(iseq.block.as(LcBlock))
            when Code::MX_NEW
                print code, ' ', iseq.value, ',', iseq.opt_v, '\n'
            when Code::OPT_CALL_INIT
                print code, ' ', iseq.argc, '\n'
            when Code::PUT_CLASS, Code::PUT_MODULE
                print code, ' ', '"', iseq.text, '"',' ', '\n'
                print_scope(iseq.jump.as(Bytecode))
            when Code::JUMP, Code::JUMPT, Code::JUMPF
                print code, ' ', iseq.jump.to_s, '\n'
            when Code::PUSHSTR
                print code, ' ', '"',iseq.text,'"', '\n'
            when Code::SET_C_T
                print code, ' ', "<catch table>", '\n'
                
        end
    end

    protected def print_method_is(is : Bytecode)
        puts "=" * 40
        method = is.method.as(LcMethod) 
        print ":arity: ", ' ', method.arity
        print ' ', ":visib:", ' ', method.visib, '\n'
        puts "=== <ARGS> ==="
        print_v_args(method.args.as(Array(VoidArgument)))
        puts "=== <BODY> ==="
        print_iseq(method.code.as(Bytecode))
        puts "=" * 40
    end

    protected def print_v_args(args : Array(VoidArgument))
        args.each do |elem|
            print elem.name, "<%s>  " % (elem.opt ? "Opt" : "Arg")
        end
        puts 
    end

    protected def print_block(block : LcBlock)
        args = block.args
        body = block.body
        puts "~" * 40
        puts "=== <ARGS> ==="
        print_v_args(args)
        puts "=== <BODY> ==="
        print_iseq(body)
        puts "~" * 40
    end

    def print_scope(code : Bytecode)
        header = "-" * 40
        puts header
        print_iseq(code)
        puts header 
    end

end