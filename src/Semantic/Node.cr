# Copyright (c) 2020 Massimiliano Dal Mas
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

module LinCAS

  abstract class Node
    property location : Location?
      
    def at(@location : Location?)
    end

    def ==(other)
      self.class == other.class 
    end  
  end

  class Program < Node
    getter filename : String, body : Body

    def initialize(@filename : String, @body : Body)
    end 
  end

  class Noop < Node
  end

  class ClassNode < Node
    property name, superclass, body, symtab

    def initialize(@name : Const | Namespace, @superclass : Node, @body : Body, @symtab : SymTable)
    end

    def_equals name, superclass, body
  end

  class ModuleNode < Node
    getter name, body, symtab

    def initialize(@name : Const | Namespace, @body : Body, @symtab : SymTable)
    end
  end

  class FunctionNode < Node
    getter visibility, receiver, name, params, body

    def initialize(@visibility, @receiver, @name, @params : Params, @body : Body, @symtab : SymTable)
    end
  end

  class Body < Node
    getter nodes : Array(Node)

    def initialize
      @nodes = [] of Node 
    end

    def <<(node : Node)
      @nodes << node 
    end

    def_equals nodes
  end

  class Block < Node

    def initialize(@params, @body)
    end
  end

  class Params 
    getter args, opt, splat, kwargs

    def initialize(@args, @opt, @splat, @kwargs)
    end
  end

  class If < Node
    getter condition, then_branch, else_branch

    def initialize(@condition : Node, @then_branch : Body, @else_branch : Body? = nil)
    end
  end

  class Select < Node
  end

  class Loop < Node
  end

  class While < Node
  end 
  
  class Until < Node 
  end 

  class For < Node 
  end 

  class Call < Node 
    getter receiver, method, params 
    def initialize(@receiver : Node, @method : String, @params : Params?)
    end
  end 

  class BinOp < Node
  end 

  class Const < Node 
  end

  class Namespace < Node 
    getter names, global 
    def initialize(@names : Array(String), @global : Bool = false)
    end
    def_equals names, global
  end

  
end