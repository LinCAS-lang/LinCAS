
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

struct LinCAS::IntermediateFactory
    
    @[AlwaysInline]
    def makeNode(nType : NodeType)
        Node.new(nType)
    end

    def makeBlock(code : Bytecode,line : Intnum)
        return IseqBlock.new(code,line)
    end

    def makeBlock(code : Block,filename : String)
        return StructBlock.new(code,filename)
    end

    def makeBCode(code : Code)
        return Bytecode.new(code)
    end

    def makeFuncArg(name : String, opt = false)
        return FuncArgument.new(name,opt)
    end
    
end
