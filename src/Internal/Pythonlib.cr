
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

  # This is just a piece of the struct
  struct PyType
    head : PyVarObject
    name : Chr*
    tp_basicsize  : LibC::Long
    tp_itemsize   : LibC::Long #For allocation

    # Methods to implement standard operations
    tp_dealloc : Void*
    tp_print   : Void*
    tp_getattr : Void*
    tp_setattr : Void*
    tp_as_async : Void* # formerly known as tp_compare (Python 2)
                                #  or tp_reserved (Python 3) 
    tp_repr : Void*

    # Method suites for standard classes
    tp_as_number : Void*
    tp_as_sequence : Void*
    tp_as_mapping : Void*

    # More standard operations (here for binary compatibility) 
    tp_hash : Void*
    tp_call : Void*
    tp_str : Void*
    tp_getattro : Void*
    tp_setattro : Void*

    # Functions to access object as input/output buffer
    tp_as_buffer : Void*
    
    # Flags to define presence of optional/expanded features
    tp_flags : LibC::ULong
    
    tp_doc : Chr* # Documentation string
    
    # Assigned meaning in release 2.0
    # call function for all accessible objects
    tp_traverse : Void*
    
    # delete references to contained objects
    tp_clear : Void*
    
    # Assigned meaning in release 2.1
    # rich comparisons
    tp_richcompare : Void*
    
    # weak reference enabler
    tp_weaklistoffset : LibC::Long
    
    # Iterators */
    tp_iter : Void*
    tp_iternext : Void*
    
    # Attribute descriptor and subclassing stuff
    tp_methods : Void*
    tp_members : Void*
    tp_getset : Void*
    tp_base : Void*
    tp_dict : PyObject
    tp_descr_get : (PyObject*, PyObject*, PyObject*) -> PyObject*
    tp_descr_set : Void*
  end

  struct CallableM
    ob_base : PyObject
    m_callable : PyObject*
    m_dict : PyObject*
  end

  enum CoFlags : LibC::Int
    CO_VARARGS = 0x0004
  end

  struct PyCodeObject
    ob_base : PyObject
    co_argcount : LibC::Int
    co_kwonlyargcount : LibC::Int
    co_nlocals : LibC::Int
    co_stacksize : LibC::Int
    co_flags : CoFlags
    co_firstlineno : LibC::Int
    # ...
  end

  struct PyFunctionObject
    ob_base         : PyObject
    func_code       : PyCodeObject*
    func_globals    : PyObject*
    func_defaults   : PyObject*
    func_kwdefaults : PyObject*
  end

  struct PyTupleObject
    ob_base : PyVarObject
    ob_item : PyObject**
  end

  $py_module_type = PyModule_Type         : PyType
  $py_function_type = PyFunction_Type     : PyType
  $py_classm_type = PyClassMethod_Type    : PyType
  $py_staticm_type = PyStaticMethod_Type  : PyType
  $py_string_type = PyString_Type         : PyType
  $py_tuple_type = PyTuple_Type           : PyType

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
  fun typeof = PyObject_Type(obj : PyObject*)                                   : PyType*
  fun call = PyObject_CallObject(func : PyObject*, args : PyObject*)            : PyObject*

  # Errors
  fun fetch_error = PyErr_Fetch(pType : PyObject**, value : PyObject**, traceback : PyObject**)
  # fun PyErr_Restore(pType : PyObject, value : PyObject, traceback : PyObject)
  fun error_occurred = PyErr_Occurred : PyObject*
  fun clear_error = PyErr_Clear

  # Modules
  fun import = PyImport_Import(name : PyObject*)          : PyObject*
  fun get_module_dict = PyModule_GetDict(obj : PyObject*) : PyObject*

  # String
  fun new_string = PyUnicode_DecodeFSDefault(str : Chr*) : PyObject*
  fun to_cstr = PyUnicode_AsUTF8(obj : PyObject*)                       : Chr*

  # Type
  fun is_subtype = PyType_IsSubtype(a : PyType*, b : PyType*) : Bool
  fun get_flags = PyType_GetFlags(t : PyType*) : TpFlags

  # Dictionary
  fun dict_get_item = PyDict_GetItem(dict : PyObject*, name : PyObject*)      : PyObject*
  fun dict_get_item_str = PyDict_GetItemString(dict : PyObject*, name : Chr*) : PyObject*

  # Tuple
  fun new_tuple = PyTuple_New(length : LibC::Int) : PyObject*
  fun tuple_set_item = PyTuple_SetItem(tuple : PyObject*, ref : LibC::Int, val : PyObject*) : LibC::Int
  fun tuple_size = PyTuple_Size(tuple : PyObject*) : LibC::Long

  # Other
  fun is_callable = PyCallable_Check(obj : PyObject*) : Bool
  fun type_lookup = _PyType_Lookup(type : Python::PyType*, obj: PyObject*) : PyObject*
end