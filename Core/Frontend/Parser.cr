
enum VoidVisib
    PUBLIC PROTECTED PRIVATE 
end
class LinCAS::Parser < LinCAS::MsgGenerator

    MATH_FUNCT     = {
        TkType::LOG, TkType::EXP, TkType::TAN, TkType::ATAN, TkType::COS, TkType::ACOS,
        TkType::SIN, TkType::ASIN, TkType::SQRT
    }

    EXP_SYNC_SET   = {
        TkType::GLOBAL_ID, TkType::LOCAL_ID, TkType::SELF, TkType::INT, TkType::FLOAT
    } + MATH_FUNCT
        
    START_SYNC_SET = { 
        TkType::IF, TkType::SELECT, TkType::DO, TkType::FOR,
        TkType::PUBLIC, TkType::PROTECTED, TkType::PRIVATE,
        TkType::VOID, TkType::CLASS, TkType::MODULE, TkType::REQUIRE,
        TkType::INCLUDE, TkType::USE, TkType::CONST, TkType::L_PAR
    } + EXP_SYNC_SET
    
    NOOP = Node.new(NodeType::NOOP)

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
        if @currentTk.ttype == TkType::LOCAL_ID
            node.addBranch(parseLocalID)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            node.addBranch(makeDummyName)
        end
    end

    macro setArity
        node.setAttr(NKey::VOID_ARITY,arity)
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
                edge = parseIDAtom
            when TkType::INT, TkType::FLOAT
                edge = parseNumberAtom
        end
    end

    macro parseBlock(condition = true)
        {% if condition %}
            if @currentTk.ttype == TkType::L_BRACE
                expandBlockInstructs
            end
        {% else %}
            expandBlockInstructs
        {% end %}
    end

    private macro expandBlockInstructs
        @nestedVoids += 1
        @block += 1 
        node.setAttr(NKey::BLOCK,parseBody)
        @block -= 1
        @nestedVoids -= 1
    end

    def initialize(@scanner : Scanner)
        @nestedVoids = 0
        @cm          = 0
        @dummyCount  = 0
        @block       = 0
        @sym         = false
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

    def displayTokens
        @tokenDisplay = true
    end

    def sourceLines
        @scanner.lines
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
            @errHandler.abortProcess if @currentTk.is_a? EofTk 
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
        nowTime = Time.now.millisecond
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
        if @withSummary
            time = Time.now.millisecond - nowTime
            msg = Msg.new(MsgType::PARSER_SUMMARY,[@scanner.lines.to_s,
                                                   @errHandler.errors.to_s,
                                                   time.to_s])
            sendMsg(msg)
        end
        return program if program
    end

    protected def parseProgram : Node
        program = @nodeFactory.makeNode(NodeType::PROGRAM)
        while !(@currentTk.is_a? EofTk)
            if !(@currentTk.ttype == TkType::ERROR)
                node = parseStmts
                program.addBranch(node)
            else
                @errHandler.flag(@currentTk,@currentTk.value,self)
            end
        end 
        program.setAttr(NKey::FILENAME,@scanner.filename)
        return program
    end

    protected def parseStmts : Node
        skipEol
        sync(START_SYNC_SET)
        tkType = @currentTk.ttype
        case tkType
            when TkType::CLASS
                return parseClass
            when TkType::MODULE
                return parseModule
            when TkType::VOID
                return parseVoid
            when TkType::PRIVATE, TkType::PROTECTED,  TkType::PUBLIC
                return parseVisibility
            #when TkType::SELECT
            #when TkType::DO
            #when TkType::IF 
            #when TkType::FOR
            when TkType::GLOBAL_ID, TkType::LOCAL_ID, TkType::FLOAT, TkType::INT,
                  TkType::TAN, TkType::ATAN, TkType::LOG, TkType::EXP, TkType::COS,
                  TkType::ACOS, TkType::SIN, TkType::ASIN, TkType::SQRT, TkType::L_PAR
                exp = parseExp
                p exp.type
                return exp
            #when TkType::CONST
            #when TkType::INCLUDE
            #when TkType::REQUIRE
            #when TkType::USE
            #when TkType::RETURN
            #when TkType::YIELD
            else
                return NOOP
        end
    ensure
        checkEol unless @currentTk.is_a? EofTk 
    end
    
    protected def parseClass : Node
        @errHandler.flag(@currentTk,ErrCode::CLASS_IN_VOID,self) if @nestedVoids > 0
        class_sync_set = 
        { 
            TkType::LOCAL_ID, TkType::INHERITS, TkType::L_BRACE, TkType::EOL
        }
        mid_sync_set =
        {
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
            node.addBranch(parseBody)
        else
            parent = @nodeFactory.makeNode(NodeType::LOCAL_ID)
            parent.setAttr(NKey::ID,"Object")
            node.setAttr(NKey::PARENT,parent)
            node.addBranch(parseBody)
        end
        @cm -= 1
        return node 
    end

    protected def parseModule : Node
        @errHandler.flag(@currentTk,ErrCode::MODULE_IN_VOID,self) if @nestedVoids > 0
        module_sync_set = 
        {
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

    protected def parseVoid : Node
        void_sync_set =
        {
            TkType::SELF, TkType::LOCAL_ID, TkType::L_PAR, 
            TkType::L_BRACE, TkType::EOL
        }
        @nestedVoids += 1
        node = @nodeFactory.makeNode(NodeType::VOID)
        if @lineSet
            setLine(node) 
        else
            @lineSet = !@lineSet
        end 
        shift
        sync(void_sync_set)
        name = parseVoidName
        node.setAttr(NKey::NAME,name)
        sync(void_sync_set)
        node.addBranch(parseVoidArgList)
        node.addBranch(parseBody)
        @nestedVoids -= 1
        return node
    end

    protected def parseVisibility : Node
        visibility = @currentTk
        shift
        @lineSet = false
        if !(@currentTk.ttype == TkType::VOID)
            @errHandler.flag(@currentTk,ErrCode::INVALID_VISIB_ARG,self)
            return parseStmts
        else
            void = parseVoid
        end
        case visibility.ttype
            when TkType::PUBLIC
                void.setAttr(NKey::VOID_VISIB,VoidVisib::PUBLIC)
            when TkType::PROTECTED
                @errHandler.flag(visibility,ErrCode::UNALLOWED_PROTECTED,self) unless @cm > 0
                void.setAttr(NKey::VOID_VISIB,VoidVisib::PROTECTED)
            when TkType::PRIVATE
                void.setAttr(NKey::VOID_VISIB,VoidVisib::PRIVATE)
        end
        return void 
    end

    protected def parseVoidName : Node
        name_sync_set = 
        {
            TkType::LOCAL_ID, TkType::DOT, TkType::L_PAR, TkType::SEMICOLON, TkType::EOL
        }
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
        elsif ALLOWED_VOID_NAMES.includes? @currentTk.text
            node = @nodeFactory.makeNode(NodeType::OPERATOR)
            node.setAttr(NKey::ID,@currentTk.text)
            return node
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            return makeDummyName
        end
    end

    protected def parseVoidArgList
        arg_sync_set = 
        {
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
        end
        if !(@currentTk.ttype == TkType::R_BRACE)
            @errHandler.flag(@currentTk,ErrCode::MISSING_L_BRACE,self)
        elsif @currentTk.is_a? EofTk
            @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_EOF,self)
            @errHandler.abortProcess
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
        while @currentTk.ttype == TkType::COLON
            shift
            namespaceCheck
        end
        return node
    end

    def parseAssign(var = nil) : Node
        assign_sync_set = {
            TkType::GLOBAL_ID, TkType::LOCAL_ID, TkType::COLON_EQ, 
            TkType::INT, TkType::FLOAT, TkType::SEMICOLON, TkType::EOL
        }
        assign_ops      = {
            TkType::PLUS_EQ, TkType::MINUS_EQ, TkType::STAR_EQ, 
            TkType::SLASH_EQ, TkType::BSLASH_EQ, TkType::MOD_EQ, TkType::POWER_EQ
        }
        sync(assign_sync_set)
        node = @nodeFactory.makeNode(NodeType::ASSIGN)
        if @currentTk.ttype == TkType::COLON_EQ && !(var)
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            node.addBranch(makeDummyName)
        end
        var = parseID unless var
        if var.as(Node).type == NodeType::METHOD_CALL
            if var.as(Node).getAttr(NKey::METHOD_NAME) != "[]"
                @errHandler.flag(@currentTk,ErrCode::INVALID_ASSIGN,self)
            end
        end
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
        return node
    end

    protected def manageAssignOps(prevNode : Node) : Node
        opTkType = @currentTk.ttype
        shift
        expr    = parseExp
        node    = @nodeFactory.makeNode(NodeType::ASSIGN)
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
        end
        node.addBranch(expNode.as(Node))
        return  node
    end

    protected def parseExp(firstNode = NOOP) : Node
        root = parseRel(firstNode)
        tkType = @currentTk.ttype
        while boolOpInclude? tkType
            node = @nodeFactory.makeNode(convertOp(tkType).as(NodeType))
            shift
            skipEol
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
        if add_op.includes? @currentTk.ttype && prevNode != NOOP
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
        while opInclude? tkType
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
                root = parseIDAtom
            when TkType::STRING
                root = parseString
            when TkType::INT, TkType::FLOAT
                root = parseNumberAtom
            when TkType::L_PAR
                shift
                root = parseSum
                if @currentTk.ttype == TkType::R_PAR
                    shift
                else
                    @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
                end
            when TkType::PI
                root = @nodeFactory.makeNode(NodeType::PI)
            when TkType::E 
                root = @nodeFactory.makeNode(NodeType::E)
            when TkType::INF
                @errHandler.flag(@currentTk,ErrCode::INF_CONST_OUT_SYM,self) unless @sym
                root = @nodeFactory.makeNode(NodeType::INF)
            when TkType::NINF
                @errHandler.flag(@currentTk,ErrCode::INF_CONST_OUT_SYM,self) unless @sym
                root = @nodeFactory.makeNode(NodeType::NINF)
            else
                @errHandler.flag(@currentTk,ErrCode::UNEXPECTED_TOKEN,self)
                shift
                root = NOOP
        end
        return parseEndAtom(root)
    end

    protected def parseEndAtom(root : Node) : Node
       while true
           case @currentTk.ttype
               when TkType::DOT
                   root = parseMethodCall(root)
               when TkType::COLON
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
        nextTkType = @nextTk.ttype
        if nextTkType == TkType::COLON
            node = parseNameSpace
        elsif {TkType::DOT_DOT, TkType::DOT_DOT_DOT}.includes? nextTkType
            node = parseRange
        elsif nextTkType == TkType::L_PAR || nextTkType == TkType::L_BRACKET
            node = parseCall
        else
            node = parseIDAtom
        end
        return node.as(Node)
    end

    protected def parseIDAtom : Node
        case @currentTk.ttype
            when TkType::LOCAL_ID
                return parseLocalID
            when TkType::GLOBAL_ID
                return parseGlobalID
            when TkType::SELF
                return @nodeFactory.makeNode(NodeType::SELF)
            else
                # Should never get here
                return NOOP
        end
    end

    protected def parseMethodCall(receiver : Node) : Node
        node = @nodeFactory.makeNode(NodeType::METHOD_CALL)
        node.addBranch(receiver)
        shift if @currentTk.ttype == TkType::DOT
        if @currentTk.ttype == TkType::LOCAL_ID
            node.addBranch(parseLocalID)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            shift
            node.addBranch(makeDummyName)
        end
        node.addBranch(parseVoidArg)
       if  @currentTk.ttype == TkType::DOT 
           node = parseMethodCall(node)
       elsif @currentTk.ttype == TkType::COLON
           node = parseNameSpace(node)
       end
       return node
    end

    protected def parseCall : Node 
        node = @nodeFactory.makeNode(NodeType::CALL)
        if @currentTk.ttype = TkType::LOCAL_ID
            node.addBranch(parseLocalID)
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_IDENT,self)
            shift
            node.addBranch(makeDummyName)
        end
        node.addBranch(parseVoidArg)
        return @currentTk.ttype == TkType::DOT ? parseMethodCall(node) : node
    end

    protected def parseNumber : Node
        case @nextTk.ttype
            when TkType::DOT
                node = parseMethodCall(parseNumberAtom)
            when TkType::DOT_DOT, TkType::DOT_DOT_DOT
                node = parseRange
                if @currentTk.ttype == TkType::DOT
                    node = parseMethodCall(node)
                end
            else
                node = parseNumberAtom
        end
        return node
    end

    protected def parseNumberAtom : Node
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
        node.setAttr(NKey::ID,@currentTk.text)
        shift
        return node
    end

    protected def parseGlobalID : Node
        node = @nodeFactory.makeNode(NodeType::GLOBAL_ID)
        node.setAttr(NKey::ID,@currentTk.text)
        shift
        return node
    end

    protected def parseVoidArg : Node
        call_sync_set = {
            TkType::L_PAR, TkType::R_PAR, TkType::COMMA, TkType::SEMICOLON,
            TkType::L_BRACE, TkType::EOL, TkType::DOT 
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
        while @currentTk.ttype = TkType::COMMA
            shift 
            node.addBranch(parseExp)
            sync(call_sync_set)
        end
        if @currentTk.ttype == TkType::R_PAR
            shift 
        else
            @errHandler.flag(@currentTk,ErrCode::MISSING_R_PAR,self)
            @errHandler.abortProcess if @currentTk.is_a? EolTk
        end 
        parseBlock
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
    
end