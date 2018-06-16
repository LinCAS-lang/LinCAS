
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

module LinCAS

    alias SymTab_t = SymTab | HybridSymT

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
            return @path.join("::")
        end

    end

    enum Allocator 
        UNDEF 
    end

    enum SType
        CLASS 
        MODULE 
        PyMODULE
        PyCLASS
    end

    class Top
        @included = [] of UInt64
    end
    
    abstract class LcBaseStruct < Top
        @path   : Path
        @id     : UInt64 = 0.to_u64
        @symTab : SymTab_t
        @methods : SymTab_t
        @statics : SymTab_t
        @type     = uninitialized SType
        @frozen   = false

        def initialize(@name : String,path : Path? = nil)
            if path
                @path = path 
            else 
                @path = Path.new
            end
            @symTab   = SymTab.new.as(SymTab_t)
            @data     = Data.new
            @methods  = SymTab.new 
            @statics  = SymTab.new
            @id       = self.object_id
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
        @gc_ref   : IntnumR = -1

        def initialize(name : String, path : Path? = nil)
            super(name,path)
        end

        def initialize(@name : String, symTab : SymTab_t,data : Data,
                       methods : SymTab_t, statics : SymTab_t,path : Path? = nil)
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

        def finalize
            Internal::PyGC.dispose(@gc_ref)
        end

        property parent,allocator,klass, gc_ref
    end 

    alias LcModule = LcClass

    enum LcMethodT
        INTERNAL
        USER
        PYTHON 
        PROC
    end

    struct FuncArgument
        @optcode : Bytecode? = nil
        def initialize(@name : String, @opt : Bool)
        end
        getter name,opt
        property optcode
    end

    class LcMethod
        @args      : Array(FuncArgument) | ::Nil = nil 
        @code      : Bytecode | LcProc   | ::Nil
        @owner     : LcClass  | LcModule | ::Nil = nil
        @arity     : IntnumR                     = 0
        @pyobj     : Python::PyObject = Python::PyObject.null
        @static    = false
        @type      = LcMethodT::INTERNAL
        @needs_gc  = false
        @gc_ref    : IntnumR = -1

        def initialize(@name : String,@visib : FuncVisib)
            @args = nil
            @code = nil
        end

        def finalize 
            Internal::PyGC.dispose(@gc_ref)
        end

        property name, args, code, owner, arity, pyobj
        property static, type, visib, needs_gc
    end 

    struct LcConst
        def initialize(@name : String,@val : Internal::Value); end
        property name,val
    end

    struct LcBlock
        @args = [] of FuncArgument
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
        @parent : SymTab_t? = nil 
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

    class HybridSymT 
        @parent : SymTab_t? = nil 
        property parent, sym_tab
        getter   pyObj

        def initialize(@pyObj : Python::PyObject)
            @sym_tab = Hash(String,LcEntry).new
        end

        def initialize(@sym_tab : Hash(String,LcEntry),@pyObj : Python::PyObject)
        end
        
        def addEntry(name,entry : LcEntry)
            @sym_tab[name] = entry
        end

        def lookUp(name)
            if tmp = @sym_tab[name]?
                return tmp 
            end
            if !(tmp = Python.PyObject_GetAttrString(@pyObj,name)).null?
                return tmp 
            else
                Python.PyErr_Clear
            end 
            nil
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