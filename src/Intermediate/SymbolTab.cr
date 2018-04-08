
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

macro attr(name)
    setter {{name.id}}
    getter {{name.id}}
end

module LinCAS

    struct Path

        def initialize(@path = Array(String).new) 
        end

        def addName(name)
            return Path.new(@path + [name])
        end

        def forceAddName(name : String)
            @path.push(name)
            return self
        end

        def copyFrom(path : Path)
            @path.clear
            path.each do |elem|
                @path << elem 
            end
            return self 
        end

        def ==(path)
            return @path == path.unsafe
        end

        def unsafe
           return @path
        end

        def to_s
            return @path.join(":")
        end

    end

    abstract class BaseEntry
        @path : Path
        def initialize(@name : String,path : Path? = nil, @prevScope : Structure? = nil)
            if path
                @path = path 
            else 
                @path = Path.new
            end
        end 
        @included = [] of Path
        @symTab   = SymTab.new
        @data     = Data.new
        @methods  = SymTab.new 
        @statics  = SymTab.new
        @id       = 0_u64
        @frozen   = false
        property name, path, prevScope, symTab, data, id, frozen
        getter included
        getter methods, statics
        def to_s 
            return @path.to_s
        end
    end

    class ClassEntry < BaseEntry
        @parent   : ClassEntry  | ::Nil

        def initialize(name, path, prevScope)
            super(name,path,prevScope)
            @parent   = nil
        end

        attr parent
    end 

    class ModuleEntry < BaseEntry
        
        def initialize(name, path, prevScope)
            super(name,path,prevScope)
        end

    end

    struct MethodEntry
        @args      : Node | ::Nil
        @code      : Node | LcProc | ::Nil
        @owner     : ClassEntry  | ModuleEntry | ::Nil
        @arity     : Intnum = 0
        @static    = false
        @internal  = false
        @singleton = false

        def initialize(@name : String,@visib : VoidVisib)
            @args = nil
            @code = nil
        end

        property name, args, code, owner, arity
        property static, internal, singleton, visib 
    end 

    class Data
        def initialize
            @data = Hash(String,LinCAS::Internal::Value).new
        end

        def addVar(var : String,value)
            @data[var] = value
        end

        def getVar(var : String)
            @data[var]?
        end

        def removeVar(var : String)
            @data.remove(var)
        end

        def clone
            newData = Data.new
            @data.each_key do |key|
                newData.addVar(key,Internal.clone_val(@data[key]))
            end
            return newData
        end

    end

    struct ConstEntry
        def initialize(@name : String,@val : Internal::Value); end
        attr name 
        attr val 
    end

    alias Entry     = MethodEntry | ClassEntry | ModuleEntry | ConstEntry
    alias Structure = ModuleEntry | ClassEntry

    class SymTab < Hash(String,LinCAS::Entry)

        def initialize
            super()
        end
        
        def addEntry(name,entry : LinCAS::Entry)
            self[name] = entry
        end

        def lookUp(name)
            return self[name]?
        end

        def removeEntry(name)
            self.delete(name)
        end

    end 

    class SymTabManager
        
        @currentScope = [] of LinCAS::Structure

        macro currentScope
            @currentScope.last
        end

        def initialize
            tmp = ClassEntry.new("Main",Path.new,nil)
            tmp.id = pointerof(tmp).address
            @currentScope.push(ClassEntry.new("Main",Path.new,nil))
        end

        @[AlwaysInline]
        protected def path 
            @currentScope.last.path
        end

        def addClass(name : String,exit = false)
            klass    = ClassEntry.new(name,path.addName(name),currentScope)
            klass.id = pointerof(klass).address
            currentScope.symTab.addEntry(name,klass)
            @currentScope.push(klass) unless exit
            return klass
        end

        def addModule(name : String, exit = false)
            mod = ModuleEntry.new(name,path.addName(name), currentScope)
            mod.id = pointerof(mod).address
            currentScope.symTab.addEntry(name,mod)
            @currentScope.push(mod) unless exit 
            return mod
        end

        def addMethod(name : String,method : MethodEntry)
            currentScope.methods.addEntry(name,method)
        end

        def addConst(name,value)
            const = ConstEntry.new(name,value)
            currentScope.symTab.addEntry(name,const)
        end

        def exitScope
            @currentScope.pop unless @currentScope.size == 1
        end 

        def enterScope(scope : Structure)
            @currentScope.push(scope)
        end

        def lookUpLocal(name)
            return currentScope.symTab.lookUp(name)
        end

        def lookUp(name)
            @currentScope.reverse_each do |layer|
                entry = layer.symTab.lookUp(name)
                return entry if entry
            end
            return @currentScope[0] if @currentScope[0].name == name
            return nil
        end

        def lookUpMethod(name)
            size = @currentScope.size - 1
            size.downto 0 do |i|
                entry = @currentScope[i].methods.lookUp(name)
                return entry if entry
            end
            return nil 
        end

        def lookUpMethodLocal(name)
            return currentScope.methods.lookUp(name)
        end

        def deleteLocal(name)
            currentScope.symTab.delete(name)
        end

        def getRoot
            return @currentScope[0]
        end

        def getCurrent
            return currentScope
        end

    end

    Id_Tab = SymTabManager.new

end
