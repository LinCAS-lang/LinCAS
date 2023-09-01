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

module LinCAS::Internal

  class LcPyObject < LcBase
    property py_obj

    def initialize(@py_obj : PyObject* = Pointer(PyObject).null)
    end

    def finalize
      Python.decref @py_obj unless @py_obj.null?
    end
  end

  @[AlwaysInline]
  def self.check_pyobject(obj : LcVal)
    if !obj.is_a? LcPyObject
      lc_raise(lc_type_err, "No implicit conversion of #{lc_typeof(obj)} into PyObject")
    end
    obj = obj.as LcPyObject
    if obj.py_obj.null?
      lc_raise(lc_runtime_err, "Uninitialized pyobject detected (#{lc_typeof(obj)})")
    end
    return obj
  end

  @[AlwaysInline]
  def self.pyobject_to_py_s(obj : PyObject*) : PyObject*
    if !is_pyunicode_obj_ex(obj)
      str = Python.to_s(obj)
    else
      str = obj
    end
    Python.incref str
    return str
  end

  @[AlwaysInline]
  def self.pyobject_any_to_s(obj : PyObject*)
    str = pyobject_to_py_s obj
    val = String.new Python.to_cstr(str)
  ensure
    Python.decref str.not_nil!
  end

  def self.object2python(obj : LcVal)
    if obj.is_a?(LcClass) && obj.type.py_embedded?
      v = obj.namespace.py_obj
      Python.incref v
      return v
    end
    id = "to_py"
    if !lc_obj_responds_to? obj, id
      lc_raise(lc_type_err, "Cannot convert #{lc_typeof(obj)} into PyObject")
    end
    tmp = check_pyobject Exec.lc_call_fun(obj, id)
    if tmp.py_obj.null?
      lc_raise(lc_runtime_err, "PyObject holds a null reference")
    end
    Python.incref tmp.py_obj
    return tmp.py_obj
  end

  def self.pyobj2lincas(obj : PyObject*)
    new_pyobj(obj)
  end

  def self.new_pyobj(obj : PyObject*)
    pytype = Python.typeof(obj)
    name = String.new pytype.value.name
    klass = lc_build_pyclass(name, pytype.as(PyObject*))
    obj = lincas_obj_alloc LcPyObject, klass, obj
    return obj
  end

  def self.lc_pyobject_allocate(klass : LcVal)
    lincas_obj_alloc LcPyObject, klass.as(LcClass)
  end

  def self.lc_pyobj_initialize(obj : LcVal, argv : LcVal)
    klass = class_of(obj)
    while klass && !klass.type.py_embedded?
      klass = klass.parent
    end
    if !klass
      lc_raise(lc_runtime_err, "Unable to find embedded python class")
    end
    args = pyarg_tuple(nil, argv.as(Ary))
    pyobj = call_pycallable(klass.not_nil!.namespace.py_obj, args)
    obj.as(LcPyObject).py_obj = pyobj
    obj
  end

  def self.lc_pyobj_to_s(obj : LcVal)
    check_pyobject obj
    str = pyobject_to_py_s obj.as(LcPyObject).py_obj
    v = build_string Python.to_cstr str
    Python.decref str
    return v
  end

  def self.init_pyobject
    @@lc_pyobject = lc_build_internal_class("PyObject")

    define_allocator(@@lc_pyobject, lc_pyobject_allocate)

    define_protected_method(@@lc_pyobject, "initialize", lc_pyobj_initialize, -1)
    define_method(@@lc_pyobject, "to_s", lc_pyobj_to_s, 0)
    define_method(@@lc_pyobject, "to_py", lc_obj_self,  0)
  end
end