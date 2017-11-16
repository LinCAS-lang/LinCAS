
class LinCAS::Node
    
    def initialize(@type : NodeType)
        @branches = [] of Node
        @parent   = uninitialized Node
        @attrs    = {} of NKey => (String | Node | Int32 | Int64 | Float32 | Float64 | VoidVisib)
    end

    protected def parent(node : Node)
        @parent = node
    end

    def parent
        @parent
    end

    def addBranch(branch : Node)
        branch.parent(self)
        @branches << branch
    end

    def setAttr(key : NKey,value)
        @attrs[key] = value
    end

    def getAttr(key : NKey)
        return @attrs[key] if @attrs.keys.includes? key
    end

end