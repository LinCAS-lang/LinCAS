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
    getter py_obj

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
    return obj.as LcPyObject
  end

  @[AlwaysInline]
  def self.pyobject_any_to_s(obj : PyObject*)
    if !is_pyunicode_obj(obj)
      str = Python.to_s(obj)
    else
      str = obj
    end
    return String.new Python.to_cstr(str)
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

  def self.new_pyobj(klass :  LcVal)
    Null
  end

  def self.init_pyobject
    @@lc_pyobject = lc_build_internal_class("PyObject")
  end
end