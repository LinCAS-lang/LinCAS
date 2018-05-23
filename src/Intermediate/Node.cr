
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class LinCAS::Node
    
    @parent : Node?
    def initialize(@type : NodeType)
        @branches = [] of Node
        @parent   = nil
        @attrs    = {} of NKey => (String | Node | Int32 | Int64 | Float32 | Float64 | FuncVisib)
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
        if value.is_a? Node 
            value.parent(self) 
        end
        @attrs[key] = value
    end

    def getAttr(key : NKey)
        return @attrs[key]?
    end

    def getAttrs
        return @attrs
    end

    def to_s
        return  @type.to_s
    end

end
