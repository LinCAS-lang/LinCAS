
# Copyright (c) 2017-2022 Massimiliano Dal Mas
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

  class LookUpTable(T, V) < Hash(T, V)
    @parent : LookUpTable(T, V)? = nil 
    property parent
    getter   py_obj

    def initialize(@py_obj : Python::PyObject? = nil)
      super()
    end

    def find(name : String, const = false) : V?
      tmp = self[name]? 
      if !tmp && @py_obj
        if !(tmp = Python.PyObject_GetAttrString(@py_obj.not_nil!,name)).null?
          if Internal.is_pycallable(tmp) && !Internal.is_pytype(tmp)
            {% if V == LcMethod %}
              tmp = Internal.pymethod_new(name, @py_obj.not_nil!, nil, false)
            {% else %}
              Internal.pyobj_decref(tmp)
              return nil 
            {% end %}
          end
          {% if V != LcMethod %}
            tmp = Internal.build_pyobj(tmp)
          {% end %}
        else
          Python.PyErr_Clear
        end 
      end
      return tmp.as(V?)
    end

    def clone 
      lookup_table = LookUpTable(T,V).new(@py_obj)
      lookup_table.merge!(self)
      lookup_table
    end

    def finalize 
    end
  end

  enum Allocator 
    UNDEF 
  end

  enum SType
    METACLASS
    CLASS 
    MODULE 
    PyMODULE
    PyCLASS
  end
  
  alias IvarTable = Hash(String, LcVal)
  alias MethodTable = LookUpTable(String, LcMethod)
  alias NameTable = LookUpTable(String, LcVal)

  abstract class LcVal
    @klass  = uninitialized LcClass
    @id     = 0_u64
    @data   = uninitialized IvarTable
    @flags  : ObjectFlags = ObjectFlags::NONE
    @gc_ref : Internal::PyGC::Ref? = nil
    property klass, data, id, flags, gc_ref
  end

  class LcClass < LcVal
    @methods   : MethodTable
    @namespace : NameTable
    @type      : SType
    @name      : String
    @parent    : LcClass? = nil
    @allocator : LcProc?  | Allocator = nil 

    property parent, allocator, gc_ref
    getter methods, namespace, type, name 

    def initialize(@type, @name, @parent = nil)
      @methods   = MethodTable.new 
      @namespace = NameTable.new
      @ivar      = IvarTable.new
    end

    def initialize(@type, @name, @parent, @methods, @namespace)
      @ivar = IvarTable.new
    end

    def initialize(@type, @name, @parent, @methods, @namespace, @ivar : IvarTable)
    end

    def is_class?
      !is_module?
    end

    def is_module?
      @type.module? || @type.py_module?
    end
  end

  # struct LcBlock
  #   @scp  : VM::Environment? = nil
  #   def initialize(@body : ISeq, @args : FuncArgSet)
  #     @me = Null.as( LcVal)
  #   end
  #   
  #   property args,scp,me
  #   getter body
  # end

  struct LcBlock
    def initialize(@iseq : ISeq, @me : LcVal, @env : VM::Environment)
    end
    getter iseq, me, env
  end

  struct OptArg
    def initialize(@name : String, @optcode : Bytecode)
    end
    getter name
    property optcode
  end

  enum LcMethodT
    INTERNAL
    USER
    PYTHON 
    PROC
  end

  class LcMethod
    @code      : ISeq | LcProc | ::Nil
    @owner     : LcClass? = nil
    @arity     : IntnumR  = 0 # used for internal methods
    @pyobj     : Python::PyObject = Python::PyObject.null
    @static    = false
    @type      : LcMethodT = LcMethodT::INTERNAL
    @needs_gc  = false
    @gc_ref    : Internal::PyGC::Ref? = nil

    def initialize(@name : String, @visib : FuncVisib)
      @code = nil
    end

    def initialize(@name : String, @visib : FuncVisib, @code : ISeq)
    end

    def finalize 
      Internal::PyGC.dispose(@gc_ref)
    end

    property name, args, code, owner, arity, pyobj
    property static, type, visib, needs_gc
  end

end