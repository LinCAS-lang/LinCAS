
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
              tmp = Internal.new_pymethod(name, @py_obj.not_nil!, nil)
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

    def ==(other)
      return object_id == other.object_id
    end
  end

  enum Allocator 
    UNDEF 
  end

  @[Flags]
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
  alias Serial = UInt32

  abstract class LcVal
  end

  abstract class LcBase < LcVal
    @klass  = nil.as LcClass?
    @id     = 0_u64
    @data   = nil.as IvarTable?
    @flags  : ObjectFlags = ObjectFlags::NONE
    @gc_ref : Internal::PyGC::Ref? = nil
    property id, flags, gc_ref
    property! klass, data
  end

  class LcClass < LcBase
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
      @data      = IvarTable.new
    end

    def initialize(@type, @name, @parent, @methods, @namespace)
      @data = IvarTable.new
    end

    def initialize(@type, @name, @parent, @methods, @namespace, @data : IvarTable)
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

  @[Flags]
  enum MethodFlags
    CACHED
    INVALIDATED

    INTERNAL
    USER
    PYTHON 
    PROC
    ATTR_READER
    ATTR_WRITER
  end

  class LcMethod
    @@global_serial : Serial = 0

    @code      : ISeq | LcProc | String | Python::PyObject | ::Nil
    @owner     : LcClass?
    @arity     : IntnumR  = 0 # used for internal methods
    @flags     : MethodFlags
    @needs_gc  = false
    @gc_ref    : Internal::PyGC::Ref? = nil
    @serial    : Serial

    def initialize(@name : String)
      @code = @owner = nil
      @flags = MethodFlags::INTERNAL
      @visib = FuncVisib::UNDEFINED
      @serial = next_serial
    end

    def initialize(@name : String, @code : LcProc, @arity : IntnumR, @owner : LcClass, @visib : FuncVisib)
      @flags = MethodFlags::INTERNAL
      @serial = next_serial
    end

    def initialize(@name : String, @code : ISeq, @owner : LcClass, @visib : FuncVisib)
      @flags  = MethodFlags::USER
      @serial = next_serial
    end

    def initialize(@name : String, @code : Python::PyObject, @owner : LcClass?, @visib : FuncVisib)
      @flags = MethodFlags::PYTHON
      @serial = next_serial
    end

    def initialize(
      @name : String, 
      @code : String, 
      @arity : IntnumR, 
      @owner : LcClass, 
      @visib : FuncVisib, 
      @flags : MethodFlags
    )
      @serial = next_serial
    end

    def finalize 
      Internal::PyGC.dispose(@gc_ref)
    end

    def next_serial
      return @@global_serial
    ensure
      if @@global_serial == Serial::MAX
        lc_bug("Reached max serial number")
      end
      @@global_serial += 1
    end

    def clear_cache
      @serial = next_serial
      @flags &= ~MethodFlags::CACHED
    end

    def cached!
      @flags |= MethodFlags::CACHED
    end

    def cached?
      @flags &= MethodFlags::CACHED
    end

    getter name, args, code, arity, pyobj,
           visib, serial
    property flags, needs_gs
    property! owner
  end

end