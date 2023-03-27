
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

class LinCAS::Reader < LinCAS::MsgGenerator

    def initialize(filename : String)
        @filename = filename
        @line     = 0
        @msgHandler = MsgHandler.new
        @msgHandler.addListener(ReaderListener.new)
        if !(File.exists?(filename))
            body = ["Invalid directory '#{filename}'"]
            sendMsg(Msg.new(MsgType::IO_ERROR,body))
            exit 0
        else
            @file     = File.open(filename,"r")
        end
    end

    def readLine
        begin
            line = @file.gets
            if line
              line += "\n"
              @line += 1
            end
            return line
        rescue exception
            body = ["#{exception}"]
            sendMsg(Msg.new(MsgType::IO_ERROR,body))
        end
    end

    def getLine 
        @line 
    end

    def close
        @file.close
    end

    def messageHandler
        @msgHandler
    end

    def getFilename
        @filename
    end
    
end
