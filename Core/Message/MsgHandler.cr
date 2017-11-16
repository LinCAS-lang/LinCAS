
class LinCAS::MsgHandler

    def initialize
        @listeners = [] of Listener
    end

    def addListener(listener : Listener)
        @listeners << listener
    end

    def removeListener(listener)
        @listeners.remove(listener)
    end 

    def sendMsg(@msg : Msg)
        notifyListeners
    end 

    private def notifyListeners
        @listeners.each do |listener|
            listener.receiveMsg(@msg.as(Msg))
        end 
    end

end