
# Copyright (c) 2017 Massimiliano Dal Mas
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

    def type
        @type
    end

    def addBranch(branch : Node)
        branch.parent(self)
        @branches << branch
    end

    def getBranches
        @branches
    end

    def setAttr(key : NKey,value)
        @attrs[key] = value
    end

    def getAttr(key : NKey)
        return @attrs[key] if @attrs.keys.includes? key
    end

    def getAttrs
        return @attrs
    end

    def to_s
        return  @type.to_s
    end

end