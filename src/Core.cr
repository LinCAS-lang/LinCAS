
module LinCAS
    EOF = "\u0003"
    ALLOWED_VOID_NAMES = 
    {
        TkType::PLUS, TkType::MINUS, TkType::STAR, TkType::SLASH, TkType::BSLASH,
        TkType::MOD, TkType::AND, TkType::OR, TkType::NOT, TkType::L_BRACKET, 
        TkType::EQ_EQ, TkType::GREATER, TkType::SMALLER, TkType::GREATER_EQ, 
        TkType::NOT_EQ, TkType::SMALLER_EQ,
        TkType::ASSIGN_INDEX
    }
    alias Intnum   = Int32 | Int64
    alias Floatnum = Float32 | Float64
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
require "./Intermediate/SymbolTab"
require "./Internal/LcInternal"
require "./Backend/CallStack"
require "./Backend/Eval"
require "../util/AstPrinter"
require "../util/SymTabPrinter"


include LinCAS

ast = nil
factory = FrontendFactory.new
ENV["libDir"] = ""
parser = factory.makeParser(File.expand_path("../Test/SampleTests/Test2.lc"))
#parser.displayTokens
ast = parser.parse
astPrinter = AstPrinter.new
#astPrinter.printAst(ast.as(Node)) if ast
evaluator = Eval.new
evaluator.eval(ast)
s_printer = SymTabPrinter.new 
s_printer.printSTab(Id_Tab.getRoot)