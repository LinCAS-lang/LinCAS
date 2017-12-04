
class LinCAS::ErrorHandler

    MAX_ERR = 10

    def initialize
        @errorCount = 0
    end

    def errors
        return @errorCount
    end
    
    def flag(token : Token, errCode , parser : Parser)
        body = [convertErrCode(errCode),
                token.line.to_s,
                token.pos.to_s,
                token.text.to_s,
                parser.filename]
        msg  = Msg.new(MsgType::SINTAX_ERROR,body)
        parser.sendMsg(msg)
        @errorCount += 1
        if @errorCount > MAX_ERR
            abortProcess(parser)
        end
    end

    def abortProcess(parser : Parser)
        msg = Msg.new(MsgType::FATAL,["Too many errors"])
        parser.sendMsg(msg)
        exit 0
    end

    def abortProcess
        exit 0
    end

end