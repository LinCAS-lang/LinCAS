
struct LinCAS::IntermediateFactory
    
    @[AlwaysInline]
    def makeNode(nType : NodeType)
        Node.new(nType)
    end
    
end