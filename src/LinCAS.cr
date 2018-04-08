
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


require "big"
module LinCAS
    EOF = "\u0003"
    ALLOWED_VOID_NAMES = 
    {
        TkType::PLUS, TkType::MINUS, TkType::STAR, TkType::SLASH, TkType::BSLASH,
        TkType::MOD, TkType::AND, TkType::OR, TkType::NOT, TkType::L_BRACKET, 
        TkType::EQ_EQ, TkType::GREATER, TkType::SMALLER, TkType::GREATER_EQ, 
        TkType::NOT_EQ, TkType::SMALLER_EQ,
        TkType::ASSIGN_INDEX, TkType::CLASS
    }
    alias IntnumR  = Int32   | Int64
    alias Floatnum = Float32 | Float64
    {% if flag?(:fast_math) %}
        alias Intnum   = IntnumR
    {% else %}
        alias Intnum   = IntnumR | BigInt
    {% end %}
    alias Num = Intnum  | Floatnum
end

require "./Listeners"
require "./Message/Msg"
require "./Message/MsgType"
require "./Message/MsgGenerator"
require "./Message/MsgHandler"
require "./Frontend/Reader"
require "./Frontend/Source"
require "./Frontend/Scanner"
require "./Frontend/Token"
require "./Frontend/TokenDictConverter"
require "./Frontend/ErrorCode"
require "./Frontend/FrontendFactory"
require "./Frontend/ErrorHandler"
require "./Frontend/ParserDict"
require "./Frontend/Parser"
require "./Intermediate/NodeType"
require "./Intermediate/Nkey"
require "./Intermediate/Node"
require "./Intermediate/IntermediateFactory"
require "./Intermediate/Bytecode"
require "./Internal/Proc"
require "./Backend/Compiler"
require "./Internal/LcInternal"
require "./Internal/Math"
require "./Backend/VM"
require "../util/AstPrinter"
require "../util/SymTabPrinter"
require "../util/Disassembler"


include LinCAS


ast = nil
factory = FrontendFactory.new
ENV["libDir"] = ""
dir = ARGV[0]?
if dir 
    #begin
        parser = factory.makeParser(File.expand_path(dir))
        #parser.displayTokens
        ast = parser.parse
        #astPrinter = AstPrinter.new
        #astPrinter.printAst(ast.as(Node)) if ast
        compiler = Compiler.new
        code   = compiler.compile(ast)
        disass = Disassembler.new 
        disass.disassemble(code)
        puts
        Exec.run(code)
        #s_printer = SymTabPrinter.new 
        #s_printer.printSTab(Id_Tab.getRoot)
    #rescue e
    #    puts e 
    #    puts
    #    Exec.lc_raise(LcInternalError,"An internal error occourred. Maybe a LinCAS bug")
    #end
end