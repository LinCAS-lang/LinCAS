
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

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
                exit 1
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
                exit 1
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
                  exit 1
            end
        end

    end

    class RuntimeListener < Listener 
        def receiveMsg(msg : Msg)
            if msg.type == MsgType::RUNTIME_ERROR
                puts msg.body[0]
                exit 1
            elsif msg.type == MsgType::BACKTRACE
                puts msg.body[0]
                exit 1
            end
        end
    end

end