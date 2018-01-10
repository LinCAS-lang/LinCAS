
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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
        def initialize(@name : String,@path : Path, @prevScope : Structure?)
        end 
        @included = [] of Path
        @symTab   = SymTab.new
        @data     = Data.new
        @methods  = SymTab.new 
        attr name
        attr path
        attr prevScope
        attr symTab
        attr data
        getter included
        getter methods
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
        @code      : Node | Symbol | ::Nil
        @owner     : ClassEntry  | ModuleEntry | ::Nil
        @arity     : Intnum = 0
        @static    = false
        @internal  = false
        @singleton = false

        def initialize(@name : String,@visib : VoidVisib)
            @args = nil
            @code = nil
        end

        attr name
        attr args
        attr code
        attr owner
        attr arity
        attr static
        attr internal
        attr singleton
        attr visib 
    end 

    class Data
        def initialize
            @data = Hash(Symbol,LinCAS::Internal::Value).new
        end

        def addVar(var : String,value)
            @data[var] = value
        end

        def addVar(var : Symbol,value)
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
            @currentScope.push(ClassEntry.new("Main",Path.new,nil))
        end

        @[AlwaysInline]
        protected def path 
            @currentScope.last.path
        end

        def addClass(name : String,exit = false)
            klass = ClassEntry.new(name,path.addName(name),currentScope)
            currentScope.symTab.addEntry(name,klass)
            @currentScope.push(klass) unless exit
            return klass
        end

        def addModule(name : String, exit = false)
            mod = ModuleEntry.new(name,path.addName(name), currentScope)
            currentScope.symTab.addEntry(name,mod)
            @currentScope.push(mod) unless exit 
            return mod
        end

        def addMethod(name : String,method : MethodEntry)
            currentScope.methods.addEntry(name,method)
        end

        def addConst(name,value)
            const = ConstEntry.new(name,value)
            currentScope.addEntry(name,value)
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
