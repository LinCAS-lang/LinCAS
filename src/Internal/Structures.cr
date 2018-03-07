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

    class LcClass < BaseEntry
        @parent   : ClassEntry  | ::Nil

        def initialize(name, path, prevScope)
            super(name,path,prevScope)
            @parent   = nil
        end

        property parent
    end 

    class LcModule < BaseEntry
        
        def initialize(name, path, prevScope)
            super(name,path,prevScope)
        end

    end

    struct VoidArgument
        @optcode : Bytecode? = nil
        def initialize(@name : String, @opt : Bool)
        end
        getter name,opt
        property optcode
    end

    struct LcMethod
        @args      : Array(VoidArgument) | ::Nil = nil 
        @code      : Bytecode | LcProc   | ::Nil
        @owner     : LcClass  | LcModule | ::Nil = nil
        @arity     : Intnum                      = 0
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

    struct LcBlock
        @args = [] of VoidArgument
        def initialize(@body : Bytecode)
        end
        property args
        getter body
    end

end