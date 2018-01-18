module LinCAS
  enum Code
    PUSHOBJ
    CALL
    POPOBJ
    STOREL
    STOREG
    PUSH_NEW_CLASS
    PUSH_NEW_MODULE
  end

  class Bytecode
    @last : Bytecode
    @next : Bytecode

    def initialize(@code : Code)
      @last = nil
      @next = nil
    end
  end
end
