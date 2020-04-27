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

  class Node
    property location : Location?
      
    def at(@location : Location?)
      self
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

    def initialize(@name : Variable | Namespace, @superclass : Node, @body : Body, @symtab : SymTable)
    end

    def_equals name, superclass, body

  end

  class ModuleNode < Node
    getter name, body, symtab

    def initialize(@name : Variable | Namespace, @body : Body, @symtab : SymTable)
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
      self 
    end

    def_equals nodes
  end

  class Assign < Node
    property left, right 

    def initialize(@left : Node, @right : Node)
    end
  end 

  class Block < Node
    getter args, splat_index, body, symtab
    def initialize(@args : Array(Node)?, @splat_index : Int32, @body : Body, @symtab : SymTable)
    end
  end

  class Params 
    getter args, opt, splat, kwargs

    def initialize(@args, @opt, @splat, @kwargs)
    end
  end

  class If < Node
    getter condition, then_branch, else_branch

    @then_branch : Body
    @else_branch : Body?

    def initialize(@condition : Node, then_branch : Node, else_branch : Node? = nil)
      if !then_branch.is_a?(Body)
        then_branch = Body.new << then_branch
      end 
      if else_branch && !else_branch.is_a?(Body) 
        else_branch = Body.new << else_branch
      end
      @then_branch = then_branch
      @else_branch = else_branch.as(Body?)
    end 

    def_equals condition, then_branch, else_branch
  end

  class Select < Node
  end

  class Loop < Node
  end

  class While < Node
    getter condition, body

    @body : Body
    def initialize(@condition : Node, body : Node)
      if !body.is_a?(Body)
        body = Body.new << body 
      end 
      @body = body.as(Body) 
    end

    def_equals condition, body
  end 
  
  class Until < Node 
    getter condition, body

    @body : Body
    def initialize(@condition : Node, body : Node)
      if !body.is_a?(Body)
        body = Body.new << body 
      end 
      @body = body.as(Body) 
    end

    def_equals condition, body
  end 

  class For < Node 
  end 

  class Call < Node 
    getter receiver, block 
    property args, named_args, block_param, name
    def initialize(@receiver    : Node?, 
                   @name        : String, 
                   @args        : Array(Node)?     = nil,
                   @named_args  : Array(NamedArg)? = nil,
                   @block_param : Node?            = nil, 
                   @block       : Node?            = nil, #change to block
                   @has_parenthesis                = true) 
    end

    def has_parenthesis?
      @has_parenthesis
    end

    def_equals receiver, name, args, named_args, block_param, block
  end 

  class NamedArg < Node
    getter name, value
    def initialize(@name : String | StringLiteral, @value : Node)
    end

    def_equals name, value
  end 

  class Splat < Node 
    getter exp 
    def initialize(@exp : Node)
    end

    def_equals exp 
  end 

  class DoubleSplat < Node
    getter exp
    def initialize(@exp : Node)
    end
    def_equals exp
  end 

  abstract class BinOp < Node
    getter left, right
    def initialize(@left : Node, @right : Node)
    end
  end 

  class And < BinOp
    def_equals left, right
  end 

  class Or < BinOp
    def_equals left, right
  end

  class ConstDef < Node 
    getter name, exp
    def initialize(@name : String, @exp : Node)
    end

    def_equals name, exp
  end

  class Namespace < Node 
    getter names, global 
    def initialize(@names : Array(String), @global : Bool = false)
    end
    def_equals names, global
  end

  class StringLiteral < Node
    getter pcs, interpolated
    def initialize(@pcs : Array(Node | String), @interpolated : Bool)
    end
    def_equals pcs, interpolated
  end

  class TrueLiteral < Node 
  end 

  class FalseLiteral < Node 
  end

  class RangeLiteral < Node
    property left, right, inclusive

    def initialize(@left : Node, @right : Node, @inclusive : Bool)
    end

    def_equals left, right, inclusive
  end 

  class ControlExpression < Node
    getter type, exp
    def initialize(@type : Symbol, @exp : Node)
    end
  end

  class OpAssign < Node 
    getter left, method, right
    def initialize(@left : Node, @method : String, @right : Node)
    end
    def_equals left, method, right
  end

  class Variable < Node
    getter name
    property type
    def initialize(@name : String, @type : ID, @is_capital = false)
    end

    def_equals name
  end

  class NumberLiteral < Node 
    getter value, type
    def initialize(@value : String, @type : Symbol)
    end 
    def_equals value, type
  end

  class SymbolLiteral < Node 
    getter name 
    def initialize(@name : String | Array(String))
    end 

    def_equals name 
  end
  
end