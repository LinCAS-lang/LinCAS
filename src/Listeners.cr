
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
