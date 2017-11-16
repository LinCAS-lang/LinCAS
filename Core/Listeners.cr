
module LinCAS

    abstract class Listener
        abstract def receiveMsg(msg : Msg)
    end

    class ReaderListener < Listener

        private IO_MSG_FORMAT = "IO Error: %s"
        
        def receiveMsg(msg : Msg)
            if msg.type == MsgType::IO_ERROR
                body = msg.body
                puts  IO_MSG_FORMAT % body[0]
                exit 0
            end
        end
    end

    class ScannerListener < Listener

        private COMMENT_ERR = " FATAL: %s\n Line %s:%s\n In: %s"

        def receiveMsg(msg : Msg)
            
            if msg.type == MsgType::COMMENT_MEETS_EOF_ERROR
                body = msg.body
                puts COMMENT_ERR % [body[0],
                                    body[1],
                                    body[2],
                                    body[3]]
                exit 0
            end
        end

    end

    class ParserListener < Listener

        FATAL_MSG         = "FATAL: %s"
        PARSER_SUM_FORMAT = "\n Source lines:       %s\n Sintax errors:      %s\n Total parsing time: %s (ms)"
        TOKEN_FORMAT      = "Type: %s; text: %s; value: %s; line: %s; position: %s"
        SINTAX_ERR_FORMAT = "\n Sintax error: %s\n Line: %s:%s on: \"%s\"\n In: %s"

        def receiveMsg(msg : Msg)
            case msg.type
                when MsgType::TOKEN
                   puts TOKEN_FORMAT % msg.body
                when MsgType::SINTAX_ERROR
                   puts SINTAX_ERR_FORMAT % msg.body
                when MsgType::PARSER_SUMMARY
                   puts PARSER_SUM_FORMAT % msg.body
                when MsgType::FATAL
                  puts FATAL_MSG % msg.body
                  exit 0
            end
        end

    end

end