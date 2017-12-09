
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

macro attr(name)
    setter {{name.id}}
    getter {{name.id}}
end

module LinCAS

    struct Path
       def initialize(@path = Tuple(String).new) 
       end

       def addName(name)
           @path += {name}
       end
       
       def removeLast
           @path = @path[0...(@path.size - 1)]
       end

       def ==(path)
           return @path == path
       end
    end

    class BaseEntry
        def initialize(@path : Path, @prevScope : SymTab)
        end 
        attr path
        attr prevScope
    end

    class ClassEntry < BaseEntry
        @name     = uninitialized String
        @parent   = uninitialized ClassEntry
        @included = uninitialized ModuleEntry
        @symTab   = SymTab.new
        @data     = Data.new
        attr name
        attr parent
        attr included
        attr symTab
        attr data
    end 

    class ModuleEntry < BaseEntry
        @name     = uninitialized String
        @included = uninitialized ModuleEntry
        @symTab   = SymTab.new
        @data     = Data.new
        attr name 
        attr included
        attr symTab
        attr data
    end

    struct MethodEntry
        #@args : Node
        #@code : Node
        @owner     = uninitialized (ClassEntry  | ModuleEntry)
        @name      = uninitialized String
        @static    = false
        @singleton = false
        attr name
        attr args
        attr static
        attr singleton
        attr code
    end 

    class Data
        def initialize
            @data = Hash(Symbol,LinCAS::Internal::Value).new
        end

        def addVar(var : String,value)
            @data[var.to_sym] = value
        end

        def getVar(var : String)
            @data[var.to_sym]?
        end

        def removeVar(var : String)
            @data.remove(var.to_sym)
        end
    end

    alias Entry = (MethodEntry | ClassEntry | ModuleEntry)

    class SymTab < Hash(Symbol,Entry)
        
    end

end