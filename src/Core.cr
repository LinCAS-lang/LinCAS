
module LinCAS
    EOF = "\u0003"
    ALLOWED_VOID_NAMES = 
    {
        TkType::PLUS, TkType::MINUS, TkType::STAR, TkType::SLASH, TkType::BSLASH,
        TkType::MOD, TkType::AND, TkType::OR, TkType::NOT, TkType::L_BRACKET, 
        TkType::EQ, TkType::GR, TkType::SM, TkType::GE, TkType::NE, TkType::SE,
        TkType::ASSIGN_INDEX
    }
    alias Intnum = (Int32 | Int64)
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
require "../util/AstPrinter"
require "./Backend/CallStack"


include LinCAS

ast = nil
factory = FrontendFactory.new
ENV["libDir"] = ""
parser = factory.makeParser(File.expand_path("../Test5.lc"))
#parser.displayTokens
#ast = parser.parse
astPrinter = AstPrinter.new
astPrinter.printAst(ast.as(Node)) if ast