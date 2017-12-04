
class LinCAS::Msg
  
  @body : Array(String)

  def initialize(type : MsgType,body : Array(String))
    @Type = type
    @body = body
  end
    
  def type
    return @Type
  end
  
  def body
    return @body
  end
    
end
