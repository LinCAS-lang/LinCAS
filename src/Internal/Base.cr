
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

    def initialize(@py_obj : Python::PyObject* = Pointer(Python::PyObject).null)
      Python.incref @py_obj if !@py_obj.null?
      super()
    end

    def find(name : String, const = false) : V?
      tmp = self[name]? 
      if !tmp && !@py_obj.null? 
        {% if V == LcMethod %}
          tmp = Internal.seek_pymethod(@py_obj, name)
        {% else %}
          if !(py = Python.get_obj_attr(@py_obj, name)).null? 
            if !Internal.is_any_method? py
              tmp = if Internal.is_pymodule py
                Internal.lc_build_pymodule name, py, self
              elsif Internal.is_pytype py
                Internal.lc_build_pyclass name, py, self
              else
                Internal.new_pyobj(py)
              end
              self[name] = tmp.as V
            else
              Python.decref(py)
            end
          else
            Python.clear_error
          end
        {% end %}
      end
      return tmp.as(V?)
    end

    def clone 
      lookup_table = LookUpTable(T,V).new(@py_obj)
      lookup_table.merge!(self)
      lookup_table
    end

    def finalize 
      Python.decref @py_obj unless @py_obj.null?
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
    PyEMBEDDED
    METACLASS
    CLASS 
    MODULE 
    # PyMODULE
    # PyCLASS
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

    def initialize(@type, @name, py_obj : Python::PyObject*, @parent = nil)
      @methods   = MethodTable.new py_obj
      @namespace = NameTable.new py_obj
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
      @type.module?
    end

    def finalize
      if @type.py_embedded?
        Python.decref(@namespace.py_obj)
      end
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
    # Inline cache
    CACHED
    INVALIDATED

    # Python method type
    FUNCTION
    STATICMETHOD
    CLASSMETHOD

    # Python instance method
    WANTS_SELF

    # Call convention
    INTERNAL
    USER
    PYTHON 
    PROC
    ATTR_READER
    ATTR_WRITER
  end

  class LcMethod
    @@global_serial : Serial = 0

    @code      : ISeq | LcProc | String | Python::PyObject* | ::Nil
    @owner     : LcClass?
    @arity     : IntnumR  = 0 # used for internal methods
    @flags     : MethodFlags
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

    def initialize(@name : String, @code : Python::PyObject*, @owner : LcClass?, @visib : FuncVisib, flags : MethodFlags)
      @flags = MethodFlags::PYTHON | flags
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
      @flags & MethodFlags::CACHED
    end

    def finalize
      if (obj = @code).is_a? Python::PyObject*
        Python.decref(obj)
      end
    end

    getter name, args, code, arity, pyobj,
           visib, serial
    property flags
    property! owner
  end

end