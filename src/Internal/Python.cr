# Copyright (c) 2017-2023 Massimiliano Dal Mas
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

require "./Pythonlib"

module LinCAS::Internal

  alias PyObject = Python::PyObject

  IMPORTED_PYCLASSES = {} of PyObject* => LcClass
  PYPATTERN          = /'.+'/

  # Taken from the CPython source code
  @[AlwaysInline]
  def self.pytype_fast_subclass(type : Python::PyType*, flags : Python::TpFlags)
    return (Python.get_flags(type) & flags) != 0
  end

  # Taken from the CPython source code
  @[AlwaysInline]
  def self.is_pytype(obj : PyObject*)
    return pytype_fast_subclass(obj.value.ob_type, Python::TpFlags::TYPE_SUBCLASS)
  end

  # Taken from the CPython source code
  def self.is_pymodule(obj : PyObject*)
    type_ptr = pointerof(Python.py_module_type)
    return obj.value.ob_type == type_ptr ||
           Python.is_subtype(obj.as(Python::PyType*), type_ptr)
  end

  # Taken from the CPython source code
  @[AlwaysInline]
  def self.is_pyunicode_obj(obj : PyObject*)
    pytype_fast_subclass(obj.value.ob_type, Python::TpFlags::UNICODE_SUBCLASS)
  end

  def self.is_any_method?(obj : PyObject*)
    return {
      pointerof(Python.py_function_type), 
      pointerof(Python.py_staticm_type), 
      pointerof(Python.py_classm_type)
    }.includes? obj.value.ob_type
  end

  @[AlwaysInline]
  def self.is_pyfunction(obj : PyObject*)
    return obj.value.ob_type == pointerof(Python.py_function_type)
  end

  @[AlwaysInline]
  private def self.exception_name(str : String)
    tmp = str.scan(PYPATTERN)
    if !tmp.empty?
      tmp = tmp[0][0]?
      return tmp if tmp 
    end
    return ""
  end

  def self.lc_raise_py_error
    Python.fetch_error(out type, out val, out tr)
    type_ = String.new type.as(Python::PyType*).value.name
    val_  = pyobject_any_to_s(val)
    {type, val, tr}.each { |x| Python.decref x}
    lc_raise(lc_pyexception," #{exception_name(type_)}: #{val_}")
  end

  @[AlwaysInline]
  def self.check_pyerror
    if !Python.error_occurred.null?
      lc_raise_py_error
    end
  end

  def self.get_python_method_class(obj : Python::PyType*, name : String)
    str = Python.to_s obj.as(PyObject*)
    m = Python.type_lookup(obj, str)
    Python.decref str
    if !m.null? && is_any_method? m
      # Python.incref m
      return m
    end
    # Python.decref m unless m.null?
    nil
  end

  def self.get_python_method_module(obj : Python::PyObject*, name : String)
    m = Python.dict_get_item_str(Python.get_module_dict(obj), name)
    if !m.null? && is_any_method? m
      # Python.incref m
      return m
    end
    nil
  end

  def self.seek_pymethod(obj : PyObject*, name : String)
    if is_pymodule(obj)
      m = get_python_method_module(obj, name)
    elsif is_pytype(obj)
      m = get_python_method_class(obj.as(Python::PyType*), name)
    else
      lc_bug("Attempted to dispatch a python method from #{
        pyobject_any_to_s(obj)
      } object")
    end
    # puts m ? "PyFound(#{name})" : "PyNotFound(#{name})"
    return m ? new_pymethod(name, m) : nil
  end

  # def self.pyarg_tuple(obj : LcVal?, args : Ary)
  #   size = args.size + (obj ? 1 : 0)
  #   tuple = Python::PyTupleObject.new
  #   tuple.ob_base.ob_base.ob_type = pointerof(Python.py_tuple_type)
  #   tuple.ob_base.ob_base.ref_count = 1
  #   tuple.ob_base.ob_size = size
  #   items = tuple.ob_item = Pointer(PyObject*).malloc(size)
  #   if obj
  #     items[0] = object2python(obj)
  #     items += 1
  #   end
  #   args.each do |arg|
  #     items[0] = object2python(arg)
  #     items += 1
  #   end
  #   return tuple
  # end

  def self.pyarg_tuple(obj : LcVal?, args : Ary)
    size = args.size + (obj ? 1 : 0)
    tuple = Python.new_tuple(size)
    i = 0
    if obj
      Python.tuple_set_item(tuple, i, object2python(obj))
      i += 1
    end
    args.each do |arg|
      Python.tuple_set_item(tuple, i, object2python(arg))
      i += 1
    end
    tuple
  end

  def self.lincas_call_python(method : LcMethod, obj : LcVal, args : Ary)
    tuple = pyarg_tuple(method.flags.wants_self? ? obj : nil, args)
    code = method.code.unsafe_as(Pointer(Python::PyObject))
    value = Python.call(code, tuple)
    Python.decref tuple
    check_pyerror
    return pyobj2lincas(value)
  end

  def self.lc_pyimport(unused, argv :  LcVal)
    argv = argv.as Ary
    name = id2string(argv[0])
    if argv.size > 1
      import_name = id2string(argv.as(Ary)[1])
    end
    str = Python.new_string(name)
    obj = Python.import(str)
    Python.decref(str)
    if !obj.null?
      _name = import_name || name.split('.').last.capitalize
      if is_pymodule obj
        import =  lc_build_pymodule _name, obj, @@lc_pymodule.namespace
      elsif is_pytype obj
        import = lc_build_pyclass _name, obj, @@lc_pymodule.namespace
      else
        lc_raise(lc_pyimport_err,"Invalid import object")
        import = Null
      end
      Python.decref(obj)
      return import
    end
    return Null
  end

  def self.init_pymodule
    @@lc_pymodule = lc_build_internal_module("Python")
    define_singleton_method(@@lc_pymodule,"pyimport", lc_pyimport,   -2)
  end
end