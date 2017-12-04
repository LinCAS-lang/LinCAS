
class LinCAS::MsgGenerator

    def addListener(msgListener)
        messageHandler.addListener(msgListener)
    end

    def removeListener(msgListener)
        messageHandler.removeMsgListener(msgListener)
    end

    def sendMsg(msg)
        messageHandler.sendMsg(msg)
    end 

end