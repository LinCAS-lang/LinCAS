
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
          end
          return line
      rescue exception
          body = ["#{exception}"]
          sendMsg(Msg.new(MsgType::IO_ERROR,body))
      end

    ensure
        @line += 1
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
