
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

@[Link(ldflags: "~/.pyenv/versions/3.7-dev/lib/python3.7/config-3.7m-darwin/libpython3.7m.a")]
lib Python
  alias Chr = LibC::Char

  @[Flags]
  enum TpFlags : LibC::ULong
    LIST_SUBCLASS    = 1 << 25
    UNICODE_SUBCLASS = 1 << 28
    TYPE_SUBCLASS    = 1 << 31
  end 

  struct PyObject
    ref_count : LibC::Long
    ob_type : PyType*
  end

  struct PyVarObject 
    ob_base : PyObject
    ob_size : LibC::Long
  end

  # This is just the head of the struct
  struct PyType
    head : PyVarObject
    name : Chr* 
  end

  $py_module_type = PyModule_Type : PyType

  # Python builders
  fun initialize = Py_Initialize
  fun finalize = Py_Finalize
  fun initialized? = Py_IsInitialized

  # GC 
  fun incref = Py_IncRef(obj : PyObject*)
  fun decref = Py_DecRef(obj : PyObject*)

  # Object
  fun to_s = PyObject_Str(obj : PyObject*)                                      : PyObject*
  fun get_obj_attr = PyObject_GetAttrString(module : PyObject*, funname : Chr*) : PyObject*   # New reference

  # Errors
  # fun PyErr_Fetch(pType : PyObject*, value : PyObject*, traceback : PyObject*)
  # fun PyErr_Restore(pType : PyObject, value : PyObject, traceback : PyObject)
  # fun PyErr_Occurred : PyObject
  fun clear_error = PyErr_Clear

  # Modules
  fun import = PyImport_Import(name : PyObject*) : PyObject*

  # String
  fun new_string = PyUnicode_DecodeFSDefault(str : Chr*) : PyObject*

  # Type
  fun is_subtype = PyType_IsSubtype(a : PyType*, b : PyType*) : Int32
  fun get_flags = PyType_GetFlags(t : PyType*) : TpFlags
end