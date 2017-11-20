
module LinCAS
    EOF = "\u0003"
    ALLOWED_VOID_NAMES = 
    {
        TkType::PLUS, TkType::MINUS, TkType::STAR, TkType::SLASH, TkType::BSLASH,
        TkType::MOD, TkType::AND, TkType::OR, TkType::NOT
    }
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
require "./Frontend/Parser"
require "./Intermediate/NodeType"
require "./Intermediate/Nkey"
require "./Intermediate/Node"
require "./Intermediate/IntermediateFactory"
require "../Util/AstPrinter"


include LinCAS

factory = FrontendFactory.new
parser = factory.makeParser("/home/massimiliano/Documenti/GitHub/crLinCAS/Test2.lc")
#parser.displayTokens
ast = parser.parse
astPrinter = AstPrinter.new
astPrinter.printAst(ast.as(Node)) if ast