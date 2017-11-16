
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
