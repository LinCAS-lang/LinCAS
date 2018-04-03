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

module LinCAS


    struct Path

        def initialize(@path = Array(String).new) 
        end

        def empty?
            return @path.size == 0 
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

    enum Allocator 
        UNDEF 
    end

    enum SType
        CLASS 
        MODULE 
    end

    class Top
        @included = [] of UInt64
    end
    
    abstract class LcBaseStruct < Top
        @path   : Path
        @id     : UInt64 = 0.to_u64
        @type     = uninitialized SType
        @frozen   = false

        def initialize(@name : String,path : Path? = nil)
            if path
                @path = path 
            else 
                @path = Path.new
            end
            @symTab   = SymTab.new
            @data     = Data.new
            @methods  = SymTab.new 
            @statics  = SymTab.new
            @id       = self.object_id
            #@included = [] of UInt64
        end 

        property name, path, symTab, data, id, frozen, type
        getter included
        getter methods, statics
        def to_s 
            return @path.to_s
        end
    end 

    class LcClass < LcBaseStruct
        @parent    : LcClass  | ::Nil
        @allocator : LcProc?  | Allocator = nil
        @parent   = nil
        @klass    = uninitialized LcClass

        def initialize(name : String, path : Path? = nil)
            super(name,path)
        end

        def initialize(@name : String, symTab : SymTab,data : Data,
                       methods : SymTab, statics : SymTab,path : Path? = nil)
            if path
                @path = path 
            else 
                @path = Path.new
            end
            @symTab  = symTab
            @data    = data 
            @methods = methods
            @statics = statics
            @id      = self.object_id
        end

        property parent,allocator,klass
    end 

    alias LcModule = LcClass

    struct VoidArgument
        @optcode : Bytecode? = nil
        def initialize(@name : String, @opt : Bool)
        end
        getter name,opt
        property optcode
    end

    class LcMethod
        @args      : Array(VoidArgument) | ::Nil = nil 
        @code      : Bytecode | LcProc   | ::Nil
        @owner     : LcClass  | LcModule | ::Nil = nil
        @arity     : Intnum                      = 0
        @static    = false
        @internal  = false

        def initialize(@name : String,@visib : VoidVisib)
            @args = nil
            @code = nil
        end

        property name, args, code, owner, arity
        property static, internal, visib 
    end 

    struct LcConst
        def initialize(@name : String,@val : Internal::Value); end
        property name,val
    end

    struct LcBlock
        @args = [] of VoidArgument
        @scp  : VM::Scope? = nil
        def initialize(@body : Bytecode)
            @me = Internal::Null.as(Internal::Value)
        end
        property args,scp,me
        getter body
    end

    struct CatchTable
        def initialize(@code : Bytecode, @var_name : String?)
        end
        getter code,var_name
    end

    alias LcEntry   = LcBaseStruct | LcMethod | LcConst
    alias Structure = LcClass

    class SymTab
        @parent : SymTab? = nil 
        property parent, sym_tab

        def initialize
            @sym_tab = Hash(String,LcEntry).new
        end

        def initialize(@sym_tab : Hash(String,LcEntry))
        end
        
        def addEntry(name,entry : LcEntry)
            @sym_tab[name] = entry
        end

        def lookUp(name)
            return @sym_tab[name]?
        end

        def removeEntry(name)
            @sym_tab.delete(name)
        end

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

end