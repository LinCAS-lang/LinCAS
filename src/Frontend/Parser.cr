
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

enum LinCAS::FuncVisib
    PUBLIC PROTECTED PRIVATE UNDEFINED
end
class LinCAS::Parser < LinCAS::MsgGenerator

    EXP_SYNC_SET   = {
        TkType::GLOBAL_ID, TkType::LOCAL_ID, TkType::CONST_ID,TkType::SELF, TkType::INT, TkType::FLOAT,
        TkType::STRING, TkType::L_BRACKET, TkType::L_PAR, TkType::PIPE, TkType::DOLLAR,
        TkType::NEW, TkType::YIELD, TkType::TRUE, TkType::FALSE, TkType::FILEMC, TkType::DIRMC,
        TkType::READS, TkType::NOT, TkType::PLUS, TkType::MINUS,TkType::NULL, TkType::ANS, TkType::L_BRACE,
        TkType::SYMBOL
    }
        
    START_SYNC_SET = { 
        TkType::IF, TkType::SELECT, TkType::DO, TkType::WHILE,TkType::FOR,
        TkType::PUBLIC, TkType::PROTECTED, TkType::PRIVATE,
        TkType::FUNC, TkType::CLASS, TkType::MODULE, TkType::REQUIRE,
        TkType::INCLUDE, TkType::USE, TkType::CONST, TkType::RETURN,
        TkType::PRINT, TkType::PRINTL, TkType::RAISE, TkType::TRY, TkType::NEXT,
        TkType::IMPORT, TkType::REQUIRE_RELATIVE
    } + EXP_SYNC_SET
    
    NOOP = Node.new(NodeType::NOOP)

    class ParserAbort < Exception
    end

    macro checkIDforReceiver
        if @currentTk.ttype == TkType::LOCAL_ID
            node = parseLocalID
            node.setAttr(NKey::RECEIVER,baseName)
            return node
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            node = makeDummyName
            node.setAttr(NKey::RECEIVER,baseName)
            return node
        end
    end

    macro namespaceCheck
        if {TkType::GLOBAL_ID, TkType::LOCAL_ID}.includes? @currentTk.ttype
            node.addBranch(parseLocalID)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            node.addBranch(makeDummyName)
        end
    end

    macro assignCheck(node = NOOP)
        if {{node}}.type == NodeType::METHOD_CALL
            if {{node}}.getBranches[0].getAttr(NKey::ID) != "[]"
                @errHandler.flag(@currentTk,ErrCode::INVALID_ASSIGN,self)
            end
        elsif !({NodeType::LOCAL_ID, NodeType::GLOBAL_ID, NodeType::CONST_ID}.includes? {{node}}.type)
            @errHandler.flag(@currentTk,ErrCode::INVALID_ASSIGN,self)
        end
    end

    macro setArity
        node.setAttr(NKey::FUNC_ARITY,arity)
    end

    macro makeOpNode(nodeType,prevNode,expr)
        expNode = @nodeFactory.makeNode({{nodeType}})
        expNode.addBranch({{prevNode}})
        expNode.addBranch({{expr}})
    end

    macro parseArg
        if @nextTk.ttype == TkType::COLON_EQ
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self) unless @currentTk.ttype == TkType::LOCAL_ID
            node.addBranch(parseAssign)
        elsif @currentTk.ttype == TkType::GLOBAL_ID
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            node.addBranch(parseGlobalID)
        elsif @currentTk.ttype == TkType::LOCAL_ID
            node.addBranch(parseLocalID)
            arity += 1
        else
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_TOKEN,self)
        end        
    end

    macro buildMatrixRow(beg = false)
        {% if beg %}
            list      = parseArrayList
            rowLength = list.getBranches.size
            node.addBranch(list)
        {% else %}
            list      = parseArrayList
            if rowLength != list.getBranches.size
                @errHandler.flag(@currentTk,ErrCode::IRREGULAR_MATRIX,self)
            end
            node.addBranch(list)
        {% end %}
    end

    macro parseRangeAtom
        case @currentTk.ttype
            when TkType::L_PAR
                shift 
                edge = parseSum
                if @currentTk.ttype == TkType::R_PAR
                    shift
                else
                    @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
                end
            when TkType::LOCAL_ID, TkType::GLOBAL_ID
                edge = parseID
            when TkType::INT, TkType::FLOAT
                edge = parseNumber
        end
    end

    macro parseBlock(condition = true)
        {% if condition %}
            if @currentTk.ttype == TkType::L_BRACE && @condition == 0
                expandBlockInstructs
            end
        {% else %}
            expandBlockInstructs
        {% end %}
    end

    private macro expandBlockInstructs
        @nestedFuncs += 1
        @block += 1 
        node.setAttr(NKey::BLOCK,parseCallBlock)
        @block -= 1
        @nestedFuncs -= 1
    end

    macro printReport
        if @withSummary
            time = Time.now.millisecond - @nowTime
            msg = Msg.new(MsgType::PARSER_SUMMARY,[@sourceLines.to_s,
                                                   @errHandler.errors.to_s,
                                                   time.to_s])
            sendMsg(msg)
            puts
        end
    end

    macro abort
        raise ParserAbort.new("") if @errHandler.handlingMsg?
        printReport
        @errHandler.abortProcess
    end

    def initialize(@scanner : Scanner)
        @nestedFuncs = 0
        @cm          = 0
        @dummyCount  = 0
        @block       = 0
        @nowTime     = 0
        @sym         = 0
        @sourceLines = 0
        @condition   = 0
        @withSummary = true
        @lineSet     = true
        @tokenDisplay = false
        @currentTk   = @scanner.currentTk.as(Token)
        @nextTk      = @scanner.nextTk.as(Token)
        @nodeFactory = IntermediateFactory.new
        @msgHandler  = MsgHandler.new
        @errHandler  = ErrorHandler.new
    end

    def messageHandler
        @msgHandler
    end

    def filename
        return @scanner.filename
    end

    def noSummary
        @withSummary = false
    end

    def singleErrOutput
        @errHandler.singleOutput
    end

    def displayTokens
        @tokenDisplay = true
    end

    def sourceLines
        @scanner.lines
    end

    def errCount
        @errHandler.errors 
    end

    def handleMsg
        @errHandler.handleMsg
    end

    def getErrMsg
        @errHandler.getErrMsg
    end

    protected def sync(syncSet)
        if !(syncSet.includes? @currentTk.ttype)
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_TOKEN,self)
            while !(syncSet.includes? @currentTk.ttype) && !(@currentTk.is_a? EofTk)
                shift
                if @currentTk.ttype == TkType::ERROR
                    @errHandler.flag(@currentTk,@currentTk.value,self)
                    shift
                end
            end  
            abort if @currentTk.is_a? EofTk
        end
    end

    protected def shift
        @currentTk = @nextTk
        @nextTk = @scanner.nextTk
    end

    protected def skipEol
        while @currentTk.ttype == TkType::EOL
            shift
        end
    end

    def parse
        @nowTime = Time.now.millisecond
        if @tokenDisplay
            while !(@currentTk.is_a? EofTk)
                if @currentTk.ttype != TkType::ERROR
                    body = {@currentTk.ttype.to_s,
                            @currentTk.text,
                            (@currentTk.value? ? @currentTk.value.to_s : nil.to_s),
                            @currentTk.line.to_s,
                            @currentTk.pos.to_s}.to_a
                    msg = Msg.new(MsgType::TOKEN,body)
                    sendMsg(msg)
                else
                    @errHandler.flag(@currentTk,@currentTk.value,self)
                end
                shift
            end
        else
            program = parseProgram
        end
        @sourceLines += @scanner.lines
        printReport
        return program if program
    end

    protected def parseProgram : Node
        program = @nodeFactory.makeNode(NodeType::PROGRAM)
        skipEol
        while !(@currentTk.is_a? EofTk)
            if !(@currentTk.ttype == TkType::ERROR)
                node = parseStmts
                program.addBranch(node)
            else
                @errHandler.flag(@currentTk,@currentTk.value,self)
                shift
            end
            skipEol
        end 
        program.setAttr(NKey::FILENAME,@scanner.filename)
        return program
    end

    protected def parseStmts : Node
        sync(START_SYNC_SET)
        tkType = @currentTk.ttype
        case tkType
            when TkType::CLASS
                return parseClass
            when TkType::MODULE
                return parseModule
            when TkType::FUNC
                return parseFunc
            when TkType::PRIVATE, TkType::PROTECTED,  TkType::PUBLIC
                return parseVisibility
            when TkType::SELECT
                return parseSelect
            when TkType::DO, TkType::WHILE
                if @nextTk.ttype == TkType::WHILE
                    shift
                    return parseWhile
                elsif @currentTk.ttype == TkType::WHILE
                    return parseWhile
                else
                    return parseUntil
                end
            when TkType::IF 
                return parseIf
            when TkType::FOR
                return parseFor
            when TkType::CONST
                return parseConst
            when TkType::INCLUDE
                return parseInclude
            when TkType::REQUIRE, TkType::REQUIRE_RELATIVE
                return parseRequire
            when TkType::IMPORT
                return parseImport
            when TkType::RETURN
                return parseReturn
            when TkType::NEXT 
                return parseNext
            when TkType::YIELD
                return  parseYield
            when TkType::PRINT, TkType::PRINTL
                return parsePrint
            when TkType::READS 
                shift
                return @nodeFactory.makeNode(NodeType::READS)
            when TkType::RAISE
                return parseRaise
            when TkType::TRY
                return parseTry
            else
                if EXP_SYNC_SET.includes? @currentTk.ttype
                    return parseExpStmt
                else
                    return NOOP
                end
        end
    ensure
        checkEol unless @currentTk.is_a? EofTk || @currentTk.ttype == TkType::R_BRACE
    end
    
    protected def parseClass : Node
        @errHandler.flag(@currentTk,ErrCode::CLASS_IN_FUNC,self) if @nestedFuncs > 0
        class_sync_set = { 
            TkType::LOCAL_ID, TkType::INHERITS, TkType::L_BRACE, TkType::EOL
        }
        mid_sync_set   = {
            TkType::LOCAL_ID, TkType::L_BRACE, TkType::EOL
        }
        @cm += 1
        node = @nodeFactory.makeNode(NodeType::CLASS)
        setLine(node)
        shift
        sync(class_sync_set)
        name = parseName
        node.setAttr(NKey::NAME,name)
        sync(class_sync_set)
        if @currentTk.ttype == TkType::INHERITS
            shift
            sync(mid_sync_set)
            if @currentTk.ttype == TkType::LOCAL_ID
                parent = parseNameSpace
            else
                @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
                parent = makeDummyName
            end
            node.setAttr(NKey::PARENT,parent)
        end
        node.addBranch(parseBody)
        @cm -= 1
        return node 
    end

    protected def parseModule : Node
        @errHandler.flag(@currentTk,ErrCode::MODULE_IN_FUNC,self) if @nestedFuncs > 0
        module_sync_set = {
            TkType::LOCAL_ID, TkType::L_BRACE, TkType::EOL
        }
        @cm += 1
        node = @nodeFactory.makeNode(NodeType::MODULE)
        setLine(node)
        shift
        sync(module_sync_set)
        node.setAttr(NKey::NAME,parseName)
        node.addBranch(parseBody)
        @cm -= 1
        return node
    end

    private def parseName : Node
        if @currentTk.ttype == TkType::LOCAL_ID
            name = parseNameSpace
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            name = makeDummyName
        end
        return name
    end

    protected def parseFunc : Node
        func_sync_set = {
            TkType::SELF, TkType::LOCAL_ID, TkType::L_PAR, 
            TkType::L_BRACE, TkType::EOL
        } + ALLOWED_FUNC_NAMES
        @nestedFuncs += 1
        node = @nodeFactory.makeNode(NodeType::Func)
        setLine(node) 
        shift
        sync(func_sync_set)
        name = parseFuncName
        node.setAttr(NKey::NAME,name)
        sync(func_sync_set)
        node.addBranch(parseFuncArgList)
        node.addBranch(parseBody)
        @nestedFuncs -= 1
        return node
    end

    protected def parseVisibility : Node
        visibility = @currentTk
        shift
        if !(@currentTk.ttype == TkType::FUNC)
            @errHandler.flag(@currentTk,ErrCode::INVALID_VISIB_ARG,self)
            return parseStmts
        else
            func = parseFunc
        end
        case visibility.ttype
            when TkType::PUBLIC
                func.setAttr(NKey::FUNC_VISIB,FuncVisib::PUBLIC)
            when TkType::PROTECTED
                @errHandler.flag(visibility,ErrCode::UNALLOWED_PROTECTED,self) unless @cm > 0
                func.setAttr(NKey::FUNC_VISIB,FuncVisib::PROTECTED)
            when TkType::PRIVATE
                func.setAttr(NKey::FUNC_VISIB,FuncVisib::PRIVATE)
        end
        return func 
    end

    protected def parseFuncName : Node
        name_sync_set = {
            TkType::LOCAL_ID, TkType::DOT, TkType::L_PAR, TkType::SEMICOLON, TkType::EOL
        } + ALLOWED_FUNC_NAMES
        if @currentTk.ttype == TkType::SELF
            node = @nodeFactory.makeNode(NodeType::SELF)
            shift
            if @currentTk.ttype == TkType::DOT 
                shift
            else
                @errHandler.flag(@currentTk,ErrCode::MISSING_DOT,self)
            end
            sync(name_sync_set)
            if @currentTk.ttype == TkType::LOCAL_ID
                node.addBranch(parseLocalID)
            else
                @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
                node.addBranch(makeDummyName)
            end 
            return node
        elsif @nextTk.ttype == TkType::COLON
            baseName = parseNameSpace
            sync(name_sync_set)
            if @currentTk.ttype == TkType::DOT
                shift
                checkIDforReceiver
            else
                @errHandler.flag(@currentTk,ErrCode::MISSING_DOT,self)
                checkIDforReceiver
            end
        elsif @nextTk.ttype == TkType::DOT
            if @currentTk.ttype == TkType::LOCAL_ID
                baseName = parseLocalID
                shift
                checkIDforReceiver
            else
                @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
                baseName = makeDummyName
                shift
                checkIDforReceiver
            end
        elsif @currentTk.ttype == TkType::LOCAL_ID
            return parseLocalID
        elsif ALLOWED_FUNC_NAMES.includes? @currentTk.ttype
            if @currentTk.ttype == TkType::L_BRACKET
                shift 
                if @currentTk.ttype != TkType::R_BRACKET
                    @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self) 
                    return makeDummyName
                else 
                    shift 
                    node = @nodeFactory.makeNode(NodeType::LOCAL_ID)
                    node.setAttr(NKey::ID,"[]")
                end 
            else
                node = @nodeFactory.makeNode(NodeType::LOCAL_ID)
                node.setAttr(NKey::ID,@currentTk.text)
                shift
            end 
            return node
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            return makeDummyName
        end
    end

    protected def parseFuncArgList
        arg_sync_set = {
            TkType::L_PAR, TkType::LOCAL_ID, TkType::COMMA, TkType::R_PAR, TkType::L_BRACE,
            TkType::EOL
        }
        node  = @nodeFactory.makeNode(NodeType::ARG_LIST)
        arity = 0
        sync(arg_sync_set)
        if @currentTk.ttype == TkType::L_PAR
            shift
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_PAR,self)
        end
        if @currentTk.ttype == TkType::R_PAR
            shift
            setArity
            return node
        end
        parseArg
        while @currentTk.ttype == TkType::COMMA
            shift
            parseArg
            sync(arg_sync_set)
        end
        if @currentTk.ttype == TkType::R_PAR
            shift
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
        end
        setArity
        return node
    end

    protected def parseBody : Node
        body_sync_set = {TkType::L_BRACE} + START_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::BODY)
        skipEol
        sync(body_sync_set)
        if !(@currentTk.ttype == TkType::L_BRACE)
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_BRACE,self)
        else
            shift
        end
        skipEol
        while (@currentTk.ttype != TkType::R_BRACE) && (@currentTk.ttype != TkType::EOF)
            node.addBranch(parseStmts)
            skipEol
        end
        if @currentTk.is_a? EofTk
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            abort
        elsif @currentTk.ttype != TkType::R_BRACE
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_BRACE,self)
        else
            shift
        end 
        return node
    end

    protected def parseNameSpace(beg = NOOP) : Node
        node = @nodeFactory.makeNode(NodeType::NAMESPACE)
        if beg != NOOP
            node.addBranch(beg)
        else
            namespaceCheck
        end
        while @currentTk.ttype == TkType::COLON2
            shift
            namespaceCheck
        end
        return node
    end

    protected def parseExpStmt : Node
        assign_ops = {
            TkType::PLUS_EQ, TkType::MINUS_EQ, TkType::STAR_EQ, TkType::SLASH_EQ, 
            TkType::BSLASH_EQ, TkType::MOD_EQ, TkType::POWER_EQ, TkType::APPEND
        }
        tk   = @currentTk
        node = parseExp
        tkType = @currentTk.ttype
        if  tkType == TkType::COLON_EQ
            node = parseAssign(node)
        elsif assign_ops.includes? tkType
            assignCheck(node)
            node = manageAssignOps(node)
        else 
            setLine(tk,node)
        end
        return node
    end

    protected def parseAssign(var = nil) : Node
        assign_sync_set = {
            TkType::GLOBAL_ID, TkType::LOCAL_ID, TkType::CONST_ID, TkType::COLON_EQ, 
            TkType::INT, TkType::FLOAT, TkType::SEMICOLON, TkType::EOL
        }
        sync(assign_sync_set)
        node = @nodeFactory.makeNode(NodeType::ASSIGN)
        setLine(node)
        if @currentTk.ttype == TkType::COLON_EQ && !(var)
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            node.addBranch(makeDummyName)
        end
        if var 
            if var.type == NodeType::CONST_ID && @nestedFuncs > 0
                @errHandler.flag(@currentTk,ErrCode::DYNAMIC_CONST,self)
            end
        else
            if @currentTk.ttype == TkType::CONST_ID && @nestedFuncs > 0
                @errHandler.flag(@currentTk,ErrCode::DYNAMIC_CONST,self)
            end
        end
        var = parseAtom unless var
        assignCheck(var)
        node.addBranch(var.as(Node))
        sync(assign_sync_set)
        if @currentTk.ttype == TkType::COLON_EQ
            shift
            skipEol
            node.addBranch(parseExp)
        elsif @currentTk.ttype == TkType::SEMICOLON || @currentTk.ttype == TkType::EOL
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_COLON_EQ,self)
            node.addBranch(parseExp)
        end
        if var.type == NodeType::CONST_ID
            tmp = @nodeFactory.makeNode(NodeType::CONST)
            tmp.addBranch(node)
            line = var.getAttr(NKey::LINE).as(Int)
            tmp.setAttr(NKey::LINE,line)
            node = tmp 
        end
        return node
    end

    protected def manageAssignOps(prevNode : Node) : Node
        node    = @nodeFactory.makeNode(NodeType::ASSIGN)
        setLine(node)
        opTkType = @currentTk.ttype
        shift
        expr    = parseExp
        expNode = nil
        node.addBranch(prevNode)
        case opTkType
            when TkType::PLUS_EQ
                makeOpNode(NodeType::SUM,prevNode,expr)
            when TkType::MINUS_EQ
                makeOpNode(NodeType::SUB,prevNode,expr)
            when TkType::STAR_EQ
                makeOpNode(NodeType::MUL,prevNode,expr)
            when TkType::SLASH_EQ
                makeOpNode(NodeType::FDIV,prevNode,expr)
            when TkType::BSLASH_EQ
                makeOpNode(NodeType::IDIV,prevNode,expr)
            when TkType::MOD_EQ
                makeOpNode(NodeType::MOD,prevNode,expr)
            when TkType::POWER_EQ
                makeOpNode(NodeType::POWER,prevNode,expr)
            when TkType::APPEND
                node = @nodeFactory.makeNode(NodeType::APPEND)
                setLine(node)
                node.addBranch(prevNode)
                node.addBranch(expr)
        end
        node.addBranch(expNode.as(Node)) if expNode
        return  node
    end

    protected def parseExp(firstNode = NOOP) : Node
        root = parseRel(firstNode)
        tkType = @currentTk.ttype
        while (boolOpInclude? tkType)
            node = @nodeFactory.makeNode(convertOp(tkType).as(NodeType))
            shift
            node.addBranch(root)
            node.addBranch(parseSubExp)
            root   = node
            tkType = @currentTk.ttype
        end
        return root
    end

    @[AlwaysInline]
    protected def parseExp2(prevNode) : Node
        if @currentTk.ttype == TkType::DOT
            call = parseMethodCall(prevNode)
        end
        parseExp(call ? call : prevNode)
    end

    protected def parseSubExp : Node
        if @currentTk.ttype = TkType::L_PAR
            shift
            skipEol
            root = parseExp
            if @currentTk.ttype == TkType::R_PAR
                shift
            else
                @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
            end
            root = parseMethodCall(root) if @currentTk.ttype == TkType::DOT
        else
            root = parseRel
        end
        return root
    end

    protected def parseRel(prevNode = NOOP) : Node
        root = parseSum(prevNode)
        tkType = @currentTk.ttype
        if opInclude? tkType
            node = @nodeFactory.makeNode(convertOp(tkType).as(NodeType))
            shift
            skipEol
            node.addBranch(root)
            node.addBranch(parseSum)
            root = node
        end
        return root
    end

    protected def parseSum(prevNode = NOOP) : Node
        add_op = {
            TkType::PLUS, TkType::MINUS
        }
        if (add_op.includes? @currentTk.ttype) && (prevNode == NOOP)
            sign = @currentTk.ttype
            shift
        end 
        root = parseProd(prevNode)
        if sign == TkType::MINUS
            node = @nodeFactory.makeNode(NodeType::INVERT)
            node.addBranch(root)
            root = node 
        end
        tkType = @currentTk.ttype  
        while add_op.includes? tkType
            node = @nodeFactory.makeNode(convertOp(tkType).as(NodeType))
            shift
            skipEol
            node.addBranch(root)
            node.addBranch(parseProd)
            root   = node
            tkType = @currentTk.ttype
        end
        return root
    end

    protected def parseProd(prevNode = NOOP) : Node
        root = parsePower(prevNode)
        tkType = @currentTk.ttype 
        while prodOpInclude? tkType
            node = @nodeFactory.makeNode(convertOp(tkType).as(NodeType))
            shift
            skipEol
            node.addBranch(root)
            node.addBranch(parsePower)
            root   = node
            tkType = @currentTk.ttype
        end 
        return root
    end

    protected def parsePower(prevNode = NOOP) : Node
        stack = [] of Node
        stack.push (prevNode != NOOP) ? prevNode : parseAtom 
        while @currentTk.ttype == TkType::POWER
            shift
            skipEol
            stack.push parseAtom
        end
        while stack.size > 1
            rightn = stack.pop
            leftn  = stack.pop
            node = @nodeFactory.makeNode(NodeType::POWER)
            node.addBranch(leftn)
            node.addBranch(rightn)
            stack.push(node)
        end 
        return stack.pop
    end

    protected def parseAtom : Node
        case @currentTk.ttype
            when TkType::LOCAL_ID, TkType::GLOBAL_ID, TkType::SELF
                if @currentTk.ttype == TkType::LOCAL_ID && @nextTk.ttype == TkType::L_PAR
                    root = parseCall
                else
                    root = parseID
                end
            when TkType::STRING
                root = parseString
            when TkType::INT, TkType::FLOAT
                root = parseNumber
            when TkType::L_PAR
                shift
                root = parseExp
                if @currentTk.ttype == TkType::R_PAR
                    shift
                else
                    @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
                end
            when TkType::PIPE
                root = parseMatrix
            when TkType::L_BRACKET
                root = parseArray
            when TkType::DOLLAR
                symbolic_sync_set = {TkType::R_BRACE, TkType::SEMICOLON, TkType::EOL} + EXP_SYNC_SET
                @errHandler.flag(@currentTk,ErrCode::ALREADY_SYM,self) if @sym > 0
                @sym += 1
                shift
                if @currentTk.ttype == TkType::L_BRACE
                    shift
                else
                    @errHandler.flag(@currentTk,ErrCode::MISSING_L_BRACE,self)
                end
                skipEol
                sync(symbolic_sync_set)
                root = @nodeFactory.makeNode(NodeType::SYMBOLIC)
                if @currentTk.ttype == TkType::R_BRACE
                    @errHandler.flag(@currentTk,ErrCode::EMPTY_FUNCTION,self)
                    shift
                else
                    root.addBranch(parseSum)
                    skipEol
                    sync(symbolic_sync_set)
                    if @currentTk.ttype == TkType::R_BRACE
                        shift 
                    else
                        @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACE,self)
                    end
                end
                @sym -= 1
            when TkType::NEW
                root = parseNew
            when TkType::NOT 
                root = @nodeFactory.makeNode(NodeType::NOT)
                shift 
                root.addBranch(parseAtom)
            when TkType::NULL 
                root = @nodeFactory.makeNode(NodeType::NULL)
                shift
            when TkType::YIELD
                root = parseYield 
            when TkType::TRUE
                root = @nodeFactory.makeNode(NodeType::TRUE)
                shift
            when TkType::FALSE
                root = @nodeFactory.makeNode(NodeType::FALSE)
                shift
            when TkType::FILEMC
                root = parseFilemc
            when TkType::DIRMC
                root = parseDirmc
            when TkType::READS
                shift
                root = @nodeFactory.makeNode(NodeType::READS)
            when TkType::CONST_ID 
                root = @nodeFactory.makeNode(NodeType::CONST_ID)
                name = @currentTk.text
                name = name[1...name.size]
                root.setAttr(NKey::ID,name)
                setLine(root)
                shift
            when TkType::ANS 
                root = @nodeFactory.makeNode(NodeType::ANS)
                shift
            when TkType::L_BRACE
                root = parseHash
            when TkType::SYMBOL
                root = @nodeFactory.makeNode(NodeType::SYMBOL)
                root.setAttr(NKey::ID,@currentTk.text)
                shift
            else
                if @currentTk.ttype == TkType::ERROR
                    @errHandler.flag(@currentTk,@currentTk.value,self)
                else
                    @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_TOKEN,self)
                end
                shift
                abort if @currentTk.is_a? EofTk
                root = parseAtom 
        end
        return parseEndAtom(root)
    end

    protected def parseEndAtom(root : Node) : Node
        while true
            case @currentTk.ttype
                when TkType::DOT, TkType::L_BRACKET
                    root = parseMethodCall(root)
                when TkType::COLON2
                    root = parseNameSpace(root)
                when TkType::DOT_DOT, TkType::DOT_DOT_DOT
                    root = parseRange(root)
                else
                    return root
            end 
        end
    end
    
    protected def parseRange(edge = NOOP) : Node
        if edge == NOOP
            parseRangeAtom
        end
        if @currentTk.ttype == TkType::DOT_DOT
            node = @nodeFactory.makeNode(NodeType::IRANGE)
        else
            node = @nodeFactory.makeNode(NodeType::ERANGE)
        end
        shift
        node.addBranch(edge)
        parseRangeAtom
        node.addBranch(edge)
        return node
    end

    protected def parseString : Node
        root = @nodeFactory.makeNode(NodeType::STRING)
        root.setAttr(NKey::VALUE,@currentTk.text)
        shift
        return root
    end

    protected def parseID : Node
        case @currentTk.ttype
            when TkType::LOCAL_ID
                return parseLocalID
            when TkType::GLOBAL_ID
                return parseGlobalID
            when TkType::SELF
                shift
                return @nodeFactory.makeNode(NodeType::SELF)
            else
                # Should never get here
                return NOOP
        end
    end

    protected def parseMethodCall(receiver : Node) : Node
        lock_index_call = false
        node = @nodeFactory.makeNode(NodeType::METHOD_CALL)
        node.setAttr(NKey::RECEIVER,receiver)
        shift if @currentTk.ttype == TkType::DOT
        if @currentTk.ttype == TkType::LOCAL_ID
            node.addBranch(parseLocalID)
        elsif (ALLOWED_FUNC_NAMES.includes? @currentTk.ttype) && (@currentTk.ttype != TkType::L_BRACKET)
            id = @nodeFactory.makeNode(NodeType::LOCAL_ID)
            id.setAttr(NKey::ID,@currentTk.text)
            shift 
            node.addBranch(id)
            lock_index_call = true
        elsif @currentTk.ttype != TkType::L_BRACKET
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            shift
            node.addBranch(makeDummyName)
        end
        if @currentTk.ttype == TkType::L_BRACKET
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_TOKEN,self) if lock_index_call
            if node.getBranches.size > 0
                args = @nodeFactory.makeNode(NodeType::ARG)
                node.addBranch(args)
                node = parseMethodCall(node)
            else
                name = @nodeFactory.makeNode(NodeType::LOCAL_ID)
                name.setAttr(NKey::ID,"[]")
                node.addBranch(name)
                node.addBranch(parseIndexArg)
            end
        else
            node.addBranch(parseCallArg)
        end
       if  {TkType::DOT, TkType::L_BRACKET}.includes? @currentTk.ttype
           node = parseMethodCall(node)
       elsif @currentTk.ttype == TkType::COLON
           node = parseNameSpace(node)
       end
       return node
    end

    protected def parseCall(methodName = NOOP) : Node 
        node = @nodeFactory.makeNode(NodeType::CALL)
        if methodName != NOOP
            node.addBranch(methodName)
        elsif @currentTk.ttype = TkType::LOCAL_ID
            node.addBranch(parseLocalID)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            shift
            node.addBranch(makeDummyName)
        end
        if @currentTk.ttype == TkType::L_BRACKET
            parseMethodCall(node)
        else
            node.addBranch(parseCallArg)
        end
        return @currentTk.ttype == TkType::DOT ? parseMethodCall(node) : node
    end

    protected def parseNumber : Node
        if @currentTk.ttype == TkType::INT
            node = @nodeFactory.makeNode(NodeType::INT)
        else
            node = @nodeFactory.makeNode(NodeType::FLOAT)
        end
        node.setAttr(NKey::VALUE, @currentTk.value.as(Int32 | Int64 | Float32 | Float64))
        shift
        return node
    end

    protected def parseLocalID : Node
        node = @nodeFactory.makeNode(NodeType::LOCAL_ID)
        setLine(node)
        node.setAttr(NKey::ID,@currentTk.text)
        shift
        return node
    end

    protected def parseGlobalID : Node
        node = @nodeFactory.makeNode(NodeType::GLOBAL_ID)
        setLine(node)
        node.setAttr(NKey::ID,@currentTk.text)
        shift
        return node
    end

    protected def parseCallArg : Node
        call_sync_set = {
            TkType::R_PAR, TkType::COMMA, TkType::SEMICOLON,
            TkType::L_BRACE, TkType::EOL
        } + EXP_SYNC_SET
        sync(call_sync_set)
        if @currentTk.ttype == TkType::L_PAR
            shift
            skipEol
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_PAR,self)
        end
        node = @nodeFactory.makeNode(NodeType::ARG)
        if @currentTk.ttype == TkType::R_PAR
            shift
            parseBlock
            return node
        end 
        if @currentTk.ttype == TkType::L_BRACE
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
            parseBlock(false)
            return node
        end
        node.addBranch(parseExp)
        sync(call_sync_set)
        while @currentTk.ttype == TkType::COMMA
            shift 
            skipEol
            sync(call_sync_set)
            node.addBranch(parseExp)
            sync(call_sync_set)
        end
        if @currentTk.ttype == TkType::R_PAR
            shift 
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
            abort if @currentTk.is_a? EolTk
        end 
        parseBlock
        return node
    end

    protected def parseIndexArg
        index_sync_set = {
            TkType::COMMA, TkType::R_BRACKET, TkType::L_PAR, TkType::SEMICOLON,
            TkType::EOL
        } + EXP_SYNC_SET
        shift
        node = @nodeFactory.makeNode(NodeType::ARG)
        sync(index_sync_set)
        if @currentTk.ttype == TkType::R_BRACKET
            shift
            return node
        end 
        node.addBranch(parseSum)
        sync(index_sync_set)
        while @currentTk.ttype == TkType::COMMA
            shift 
            node.addBranch(parseSum)
            sync(index_sync_set)
        end 
        if @currentTk.ttype == TkType::R_BRACKET
            shift 
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACKET,self)
        end 
        return node
    end

    protected def parseCallBlock : Node
        shift 
        skipEol
        node = @nodeFactory.makeNode(NodeType::BLOCK)
        if @currentTk.ttype == TkType::L_PAR
            node.setAttr(NKey::BLOCK_ARG,parseFuncArgList)
            skipEol
        end
        while (@currentTk.ttype != TkType::R_BRACE) && !(@currentTk.is_a? EofTk)
            node.addBranch(parseStmts)
        end
        tkType = @currentTk.ttype
        if tkType == TkType::EOF
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            abort
        elsif tkType != TkType::R_BRACE
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACE,self)
        else
            shift 
        end
        return node
    end

    protected def parseMatrix
        matrix_sync_set = {
            TkType::PIPE, TkType::SEMICOLON, TkType::EOL
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::MATRIX)
        shift 
        sync(matrix_sync_set)
        if @currentTk.ttype == TkType::PIPE
            shift
            return node
        end
        buildMatrixRow(true)
        sync(matrix_sync_set)
        while @currentTk.ttype == TkType::SEMICOLON
            shift 
            skipEol
            sync(matrix_sync_set)
            buildMatrixRow
            sync(matrix_sync_set)
        end 
        if @currentTk.ttype == TkType::PIPE
            shift
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_PIPE,self)
        end
        return node
    end

    protected def parseArray
        array_sync_set = {
            TkType::R_BRACKET, TkType::SEMICOLON, TkType::EOL
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::ARRAY)
        shift
        skipEol
        sync(array_sync_set)
        if @currentTk.ttype == TkType::R_BRACKET
            shift 
            return node 
        end 
        arrayList = parseArrayList
        arrayList.getBranches.each do |el|
            node.addBranch(el)
        end
        skipEol
        sync(array_sync_set)
        if @currentTk.ttype == TkType::R_BRACKET
            shift
        else 
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACKET,self)
        end 
        return node
    end

    protected def parseArrayList
        list_sync_set = {
            TkType::COMMA, TkType::PIPE, TkType::R_BRACKET, TkType::SEMICOLON, TkType::EOL
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::ARRAY_LIST)
        sync(list_sync_set)
        node.addBranch(parseExp)
        sync(list_sync_set)
        while @currentTk.ttype == TkType::COMMA
            shift 
            skipEol
            sync(list_sync_set)
            node.addBranch(parseExp)
            sync(list_sync_set)
        end
        return node
    end

    protected def parseNew
        eol_set      = {TkType::SEMICOLON, TkType::EOL}
        new_sinc_set = {
            TkType::GLOBAL_ID, TkType::LOCAL_ID
        } + eol_set
        mid_set      = {
            TkType::R_PAR
        } + eol_set + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::NEW)
        setLine(node)
        shift
        sync(new_sinc_set)
        if {TkType::GLOBAL_ID, TkType::LOCAL_ID}.includes? @currentTk.ttype
            node.addBranch(parseNameSpace)
            sync(mid_set)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_NAME,self)
        end
        node.addBranch(parseCallArg)
        return node
    end

    protected def parseFilemc
        node = @nodeFactory.makeNode(NodeType::STRING)
        node.setAttr(NKey::VALUE,@scanner.filename)
        shift
        return node
    end

    protected def parseDirmc
        node = @nodeFactory.makeNode(NodeType::STRING)
        node.setAttr(NKey::VALUE,File.dirname(@scanner.filename))
        shift 
        return node
    end

    protected def parseSelect : Node 
        select_sync_set = {
            TkType::L_BRACE, TkType::CASE, TkType::R_BRACE, TkType::EOL
        } + EXP_SYNC_SET 
        node = @nodeFactory.makeNode(NodeType::SELECT)
        setLine(node)
        shift
        sync(select_sync_set)
        if !(EXP_SYNC_SET.includes? @currentTk.ttype)
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
        else
            node.addBranch(parseExp)
        end
        parseSelectBlock(node)
        return node 
    end

    protected def parseSelectBlock(node : Node) : ::Nil
        block_sync_set   = {
            TkType::L_BRACE, TkType::R_BRACE, TkType::SEMICOLON, TkType::EOL 
        }
        block_mid_set    = {
            TkType::CASE
        }  + block_sync_set
        block_follow_set = {
            TkType::ELSE
        }  + block_mid_set
        skipEol
        sync(block_sync_set)
        if @currentTk.ttype == TkType::L_BRACE
            shift
            skipEol
            sync(block_mid_set)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_BRACE,self)
        end
        if @currentTk.ttype == TkType::R_BRACE
            @errHandler.flag(@currentTk,ErrCode::EXPECTING_CASE,self)
            shift
            return 
        end
        if @currentTk.ttype != TkType::CASE
            @errHandler.flag(@currentTk,ErrCode::EXPECTING_CASE,self)
        end
        while @currentTk.ttype != TkType::R_BRACE && !(@currentTk.is_a? EofTk)
            tkType = @currentTk.ttype
            if tkType == TkType::CASE
                shift
                selectNode = @nodeFactory.makeNode(NodeType::CASE)
                selectNode.addBranch(parseOptList)
                selectNode.addBranch(parseBody)
                node.addBranch(selectNode)
            elsif tkType == TkType::ELSE 
                shift 
                elseNode = @nodeFactory.makeNode(NodeType::ELSE)
                elseNode.addBranch(parseBody)
                node.addBranch(elseNode)
            end 
            skipEol
            sync(block_follow_set)
        end
        if @currentTk.ttype == TkType::R_BRACE
            shift
        elsif @currentTk.is_a? EofTk
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            abort 
        else 
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACE,self)
        end 
    end

    protected def parseOptList : Node 
        opt_sync_set = {
            TkType::COMMA, TkType::L_BRACE
        } + EXP_SYNC_SET
        sync(opt_sync_set)
        node = @nodeFactory.makeNode(NodeType::OPT_SET)
        if @currentTk.ttype == TkType::L_BRACE
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
            return node
        end
        node.addBranch(parseExp)
        sync(opt_sync_set) unless @currentTk.ttype == TkType::EOL
        while @currentTk.ttype == TkType::COMMA
            shift
            skipEol
            node.addBranch(parseExp)
            sync(opt_sync_set) unless @currentTk.ttype == TkType::EOL
        end 
        return node
    end

    protected def parseWhile : Node
        while_sync_set = {
            TkType::L_BRACE, TkType::EOL
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::WHILE)
        setLine(node)
        shift
        sync(while_sync_set)
        if !(EXP_SYNC_SET.includes? @currentTk.ttype)
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
        else
            @condition += 1
            node.addBranch(parseExp)
            @condition -= 1
        end 
        node.addBranch(parseBody)
        return node
    end

    protected def parseUntil : Node
        node = @nodeFactory.makeNode(NodeType::UNTIL)
        body = @nodeFactory.makeNode(NodeType::BODY)
        setLine(node)
        shift 
        skipEol
        while @currentTk.ttype != TkType::UNTIL && !(@currentTk.is_a? EofTk)
            body.addBranch(parseStmts)
            skipEol
        end 
        node.addBranch(body)
        if @currentTk.is_a? EofTk
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            abort
        elsif @currentTk.ttype != TkType::UNTIL
            @errHandler.flag(@currentTk,ErrCode::MISSING_UNTIL,self)
        else
            shift
        end 
        @condition += 1
        condition = parseExp
        @condition -= 1
        setLine(condition)
        node.addBranch(condition)
        return node 
    end

    protected def parseIf : Node
        if_sync_set = {
            TkType::THEN, TkType::L_BRACE, TkType::EOL 
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::IF)
        setLine(node)
        shift 
        sync(if_sync_set)
        tkType = @currentTk.ttype
        if {TkType::THEN, TkType::L_BRACE}.includes? tkType
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
        else
            @condition += 1
            node.addBranch(parseExp)
            @condition -= 1
        end 
        sync(if_sync_set)
        shift if @currentTk.ttype == TkType::THEN
        node.addBranch(parseThenBody)
        while @currentTk.ttype == TkType::EOL && @nextTk.ttype == TkType::EOL
            shift 
        end 
        shift if {TkType::ELSE, TkType::ELSIF}.includes? @nextTk.ttype
        if @currentTk.ttype == TkType::ELSIF
            node.addBranch(parseIf)
        elsif @currentTk.ttype == TkType::ELSE 
            shift 
            node.addBranch(parseBody)
        end 
        return node
    end

    protected def parseThenBody : Node
        then_sync_set = {
            TkType::L_BRACE, TkType::R_BRACE, TkType::ELSE
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::BODY)
        skipEol
        sync(then_sync_set)
        if @currentTk.ttype == TkType::L_BRACE
            shift 
            skipEol
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_BRACE,self)
        end 
        while @currentTk.ttype != TkType::R_BRACE && !(@currentTk.is_a? EofTk) && @currentTk.ttype != TkType::ELSE
            node.addBranch(parseStmts)
            skipEol
        end 
        if @currentTk.is_a? EofTk
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            abort
        elsif @currentTk.ttype != TkType::R_BRACE
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACE,self)
        else
            shift
        end
        return node
    end

    protected def parseFor : Node
        for_sync_set = {
            TkType::COLON, TkType::TO, TkType::DOWNTO, TkType::L_BRACE, TkType::EOL
        } + EXP_SYNC_SET
        node     = @nodeFactory.makeNode(NodeType::BODY)
        loopNode = @nodeFactory.makeNode(NodeType::WHILE)
        oneNode  = @nodeFactory.makeNode(NodeType::INT)
        oneNode.setAttr(NKey::VALUE,1)
        setLine(node)
        shift 
        sync(for_sync_set)
        if {TkType::GLOBAL_ID, TkType::LOCAL_ID}.includes? @currentTk.ttype
            var = parseID
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            var = makeDummyName
        end 
        sync(for_sync_set)
        if @currentTk.ttype == TkType::COLON
            shift 
        else 
            @errHandler.flag(@currentTk,ErrCode::MISSING_COLON,self)
        end 
        sync(for_sync_set)
        if EXP_SYNC_SET.includes? @currentTk.ttype
            beg = parseSum
            sync(for_sync_set)
        else 
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
            beg = oneNode
        end
        assignNode = @nodeFactory.makeNode(NodeType::ASSIGN)
        assignNode.addBranch(var)
        assignNode.addBranch(beg)
        node.addBranch(assignNode)
        tkType = @currentTk.ttype
        if tkType == TkType::TO
            condition = @nodeFactory.makeNode(NodeType::SE)
            op        = @nodeFactory.makeNode(NodeType::SUM)
            shift
        elsif tkType == TkType::DOWNTO
            condition = @nodeFactory.makeNode(NodeType::GE)
            op        = @nodeFactory.makeNode(NodeType::SUB)
            shift
        else 
            @errHandler.flag(@currentTk,ErrCode::MISSING_DIR,self)
            condition = @nodeFactory.makeNode(NodeType::SE)
            op        = @nodeFactory.makeNode(NodeType::SUM)
        end 
        condition.addBranch(var)
        op.addBranch(var)
        op.addBranch(oneNode)
        sync(for_sync_set)
        if EXP_SYNC_SET.includes? @currentTk.ttype 
            condition.addBranch(parseSum)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
        end
        loopNode.addBranch(condition)
        body     = parseBody
        increase = @nodeFactory.makeNode(NodeType::ASSIGN)
        increase.addBranch(var)
        increase.addBranch(op)
        body.addBranch(increase)
        loopNode.addBranch(body)
        node.addBranch(loopNode)
        return node
    end

    protected def parseConst : Node
        const_sync_set = {
            TkType::COLON_EQ, TkType::SEMICOLON, TkType::EOL
        }
        if @nestedFuncs > 0
            @errHandler.flag(@currentTk,ErrCode::DYNAMIC_CONST,self)
        end 
        node = @nodeFactory.makeNode(NodeType::CONST)
        setLine(node)
        shift 
        sync(EXP_SYNC_SET)
        if {TkType::GLOBAL_ID, TkType::LOCAL_ID}.includes? @currentTk.ttype 
            id = parseID 
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            id = makeDummyName
        end 
        sync(const_sync_set)
        node.addBranch(parseAssign(id))
        return node 
    end

    protected def parseInclude : Node
        node = @nodeFactory.makeNode(NodeType::INCLUDE)
        setLine(node)
        shift 
        node.addBranch(parseNameSpace)
        return node
    end

    protected def parseRequire : Node
        require_sync_set = {
            TkType::SEMICOLON, TkType::EOL
        }
        frontendFact = FrontendFactory.new
        node = @nodeFactory.makeNode(NodeType::REQUIRE)
        node.setAttr(NKey::ID,@currentTk.ttype == TkType::REQUIRE ? "require" : "require_relative")
        setLine(node)
        shift 
        node.addBranch(parseExp)
        return node 
    end

    protected def parseImport : Node
        use_sync_set = {
            TkType::SEMICOLON, TkType::EOL
        }
        node = @nodeFactory.makeNode(NodeType::IMPORT)
        setLine(node)
        shift 
        node.addBranch(parseExp)
        return node 
    end

    protected def parseReturn : Node
        @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_RETURN,self) unless @nestedFuncs > 0
        @errHandler.flag(@currentTk,ErrCode::RETURN_IN_BLOCK,self) if @block > 0
        node = @nodeFactory.makeNode(NodeType::RETURN)
        setLine(node)
        shift 
        unless {TkType::SEMICOLON, TkType::EOL}.includes? @currentTk.ttype
            sync(EXP_SYNC_SET)
            node.addBranch(parseExp)
        else
            nullNode = @nodeFactory.makeNode(NodeType::NULL)
            node.addBranch(nullNode)
        end
        return node
    end

    protected def parseNext : Node 
        @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_NEXT,self) unless @block > 0
        node = @nodeFactory.makeNode(NodeType::NEXT)
        setLine(node)
        shift 
        unless {TkType::SEMICOLON, TkType::EOL}.includes? @currentTk.ttype
            sync(EXP_SYNC_SET)
            node.addBranch(parseExp)
        else
            nullNode = @nodeFactory.makeNode(NodeType::NULL)
            node.addBranch(nullNode)
        end
        return node
    end

    protected def parseYield : Node
        @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_YIELD,self) unless @nestedFuncs > 0
        node = @nodeFactory.makeNode(NodeType::YIELD)
        setLine(node)
        shift
        if @currentTk.ttype == TkType::L_PAR
            node.addBranch(parseCallArg)
        end 
        return node
    end

    protected def parsePrint : Node
        print_sync_set = {
            TkType::COMMA, TkType::SEMICOLON, TkType::R_BRACE, TkType::EOL 
        } + EXP_SYNC_SET
        if @currentTk.ttype == TkType::PRINT
            node = @nodeFactory.makeNode(NodeType::PRINT)
        else
            node = @nodeFactory.makeNode(NodeType::PRINTL)
        end 
        setLine(node) 
        shift 
        unless {TkType::SEMICOLON, TkType::EOL, TkType::R_BRACE}.includes? @currentTk.ttype
            sync(EXP_SYNC_SET)
            node.addBranch(parseExp)
            sync(print_sync_set)
            while @currentTk.ttype == TkType::COMMA
                shift 
                skipEol
                sync(EXP_SYNC_SET)
                node.addBranch(parseExp)
                sync(print_sync_set)
            end 
        end 
        return node 
    end

    protected def parseRaise : Node
        node = @nodeFactory.makeNode(NodeType::RAISE)
        setLine(node)
        shift 
        if {TkType::SEMICOLON, TkType::EOL}.includes? @currentTk.ttype
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self) 
        else
            sync(EXP_SYNC_SET)
            node.addBranch(parseExp)
        end 
        return node
    end

    protected def parseTry
        node = @nodeFactory.makeNode(NodeType::TRY)
        setLine(node)
        shift
        node.addBranch(parseBody)
        while @currentTk.ttype == TkType::EOL && @nextTk.ttype == TkType::EOL
            shift 
        end 
        shift if @nextTk.ttype == TkType::CATCH 
        if @currentTk.ttype == TkType::CATCH 
            catchNode = @nodeFactory.makeNode(NodeType::CATCH)
            shift 
            if {TkType::LOCAL_ID, TkType::GLOBAL_ID}.includes? @currentTk.ttype
                catchNode.addBranch(parseID)
            end
            catchNode.addBranch(parseBody)
            node.addBranch(catchNode)
        end 
        return node
    end

    protected def parseHash
        hash_sync_set = {
            TkType::COMMA, TkType::R_BRACE, TkType::EOL, TkType::SEMICOLON
        } + EXP_SYNC_SET
        node = @nodeFactory.makeNode(NodeType::HASH)
        setLine(node)
        shift
        if @currentTk.ttype == TkType::R_BRACE
            shift
            return node 
        end
        node.addBranch(parseHashAtom)
        sync(hash_sync_set)
        while @currentTk.ttype != TkType::R_BRACE && !(@currentTk.is_a? EofTk) && @currentTk.ttype == TkType::COMMA
            shift
            skipEol
            node.addBranch(parseHashAtom)
            sync(hash_sync_set)
        end
        if @currentTk.ttype == TkType::R_BRACE
            shift
        elsif @currentTk.is_a? EofTk
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            abort
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_BRACE,self)
        end
        return node 
    end

    protected def parseHashAtom
        sync_set = { TkType::ARROW, TkType::EOL, TkType::COMMA } + EXP_SYNC_SET
        sync(sync_set)
        node = @nodeFactory.makeNode(NodeType::HASH_ATOM)
        if !(EXP_SYNC_SET.includes? @currentTk.ttype )
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
            tmp = NOOP
        else
            tmp = parseExp
        end
        node.addBranch(tmp)
        sync(sync_set)
        if !(@currentTk.ttype == TkType::ARROW)
            @errHandler.flag(@currentTk,ErrCode::MISSING_ARROW,self)
        else
            shift
            sync(sync_set)
        end
        if !(EXP_SYNC_SET.includes? @currentTk.ttype)
            @errHandler.flag(@currentTk,ErrCode::MISSING_EXPR,self)
            tmp = NOOP
        else
            tmp = parseExp
        end
        node.addBranch(tmp)
        return node
    end

    @[AlwaysInline]
    protected def checkEol : ::Nil
        if (@currentTk.ttype == TkType::SEMICOLON) || (@currentTk.is_a? EolTk)
            shift
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_EOL,self)
        end
    end

    private def makeDummyName : Node
        node = @nodeFactory.makeNode(NodeType::LOCAL_ID)
        node.setAttr(NKey::ID,"DummyName_#{@dummyCount += 1}")
        return node
    end

    @[AlwaysInline]
    private def setLine(node : Node) : ::Nil
        node.setAttr(NKey::LINE,@currentTk.line)
    end

    @[AlwaysInline]
    private def setLine(tk : Token, node : Node)
        node.setAttr(NKey::LINE,tk.line)
    end
    
end
