
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

@[Link("python3.5m")]
lib Python
    {% if flag?(:x86_64) %}
        alias PyLong = Int64 
    {% else %}
        alias PyLong = Int32 
    {% end %}

    alias PyObject = Void*
    alias Chr = LibC::Char
    struct PyComplex 
        real : Float64 
        imag : Float64
    end

    # Python builders
    fun Py_Initialize
    fun Py_Finalize
    fun Py_IsInitialized

    # GC 
    fun Py_IncRef(obj : PyObject)
    fun Py_DecRef(obj : PyObject)

    # Errors
    fun PyErr_Fetch(pType : PyObject*, value : PyObject*, traceback : PyObject*)
    fun PyErr_Restore(pType : PyObject, value : PyObject, traceback : PyObject)
    fun PyErr_Occurred : PyObject

    # Strings 
    fun PyUnicode_AsUTF8(obj : PyObject)                       : Chr*
    fun PyUnicode_AsUTF8AndSize(obj : PyObject,size : PyLong*) : Chr*
    fun PyUnicode_DecodeFSDefault(str : Chr*)                  : PyObject

    # Numbers
    fun PyLong_FromLong(n : Int64)      : PyObject
    fun PyLong_AsLong(n : PyObject)     : Int64
    fun PyFloat_FromDouble(d : Float64) : PyObject
    fun PyFloat_AsDouble(f : PyObject)  : Float64
    fun PyComplex_FromCComplex(z : PyComplex)                 : PyObject
    fun PyComplex_FromDoubles(real : Float64, imag : Float64) : PyObject
    fun PyComplex_AsCComplex(z : PyObject)                    : PyComplex

    # Object
    fun PyObject_Str(obj : PyObject)                              : PyObject
    fun PyObject_GetAttrString(module : PyObject, funname : Chr*) : PyObject
    fun PyObject_GetAttr(obj : PyObject, attr : PyObject)         : PyObject
    fun PyObject_CallObject(func : PyObject, args : PyObject)     : PyObject
    fun PyObject_Type(obj : PyObject)                             : PyObject
    fun PyObject_TypeCheck(obj : PyObject, ptype : PyObject)      : Int32
    fun PyObject_IsTrue(obj : PyObject)                           : Int32 
    fun PyObject_IsInstance(obj : PyObject, klass : PyObject)     : Int32
    
    # Modules
    fun PyImport_Import(name : PyObject) : PyObject
    fun PyImport_ImportModuleEx(name : Chr*, globals : PyObject, locals : PyObject, fromlist : PyObject) : PyObject
    fun PyModule_GetDict(obj : PyObject) : PyObject
        
    
    # Tuple
    fun PyTuple_New(length : LibC::Int) : PyObject
    fun PyTuple_SetItem(tuple : PyObject, ref : LibC::Int, val : PyObject)

    # Functions 
    fun PyInstanceMethod_Function(m : PyObject) : PyObject
    fun PyMethod_Function(m : PyObject)         : PyObject
    fun PyMethod_Self(m : PyObject)             : PyObject

    # Dictionary
    fun PyDict_GetItem(dict : PyObject, name : PyObject)   : PyObject
    fun PyDict_GetItemString(dict : PyObject, name : Chr*) : PyObject
    
    # Checks
    fun PyFloat_Check(obj : PyObject)          : Int32 
    fun PyLong_Check(obj : PyObject)           : Int32
    fun PyType_Check(obj : PyObject)           : Int32
    fun PyUnicode_Check(obj : PyObject)        : Int32
    fun PyModule_Check(obj : PyObject)         : Int32
    fun PyCallable_Check(obj : PyObject)       : Int32
    fun PyFunction_Check(obj : PyObject)       : Int32
    fun PyMethod_Check(obj : PyObject)         : Int32
    fun PyInstanceMethod_Check(obj : PyObject) : Int32
    fun PyDict_Check(obj : PyObject)           : Int32

    fun PyFloat_CheckExact(obj : PyObject)     : Int32
    fun PyLong_CheckExact(obj : PyObject)      : Int32
    fun PyType_CheckExact(obj : PyObject)      : Int32
    fun PyUnicode_CheckExact(obj : PyObject)   : Int32
    fun PyModule_CheckExact(obj : PyObject)    : Int32
    fun PyDict_CheckExact(obj : PyObject)      : Int32
    
end

