
struct LinCAS::IntermediateFactory

    def makeNode(nType : NodeType)
        return Node.new(nType)
    end
    
end