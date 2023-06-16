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

  # Taken from the CPython source code
  @[AlwaysInline]
  def self.pytype_fast_subclass(type : Python::PyType*, flags : Python::TpFlags)
    return (Python.get_flags(type) & flags) == 0
  end

  def self.is_pycallable(*any)
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

  def self.lc_pyimport(unused, argv :  LcVal)
    argv = argv.as Ary
    name = id2string(argv[0])
    if argv.size > 1
      import_name = id2string(argv.as(Ary)[1])
    end
    str = Python.new_string(name)
    obj = Python.import(str)
    Python.decref(str)
    puts "OK!"
    if !obj.null?
      _name = import_name || name.split('.').last
      if is_pymodule obj
        import =  lc_new_pymodule _name, obj, @@lc_pymodule.namespace
      elsif is_pytype obj
        import = Null
      else
        lc_raise(lc_pyimport_err,"Invalid import object")
        Python.decref(obj)
        import = Null
      end
      return import
    end
    return Null
  end

  def self.init_pymodule
    @@lc_pymodule = lc_build_internal_module("Python")
    define_singleton_method(@@lc_pymodule,"pyimport", lc_pyimport,   -2)
  end
end