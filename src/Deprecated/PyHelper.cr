

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

module LinCAS::Internal
    {% if flag?(:x86_64) %}
        Py_TPFLAGS_LIST_SUBCLASS    = 1_u64 << 25
        Py_TPFLAGS_UNICODE_SUBCLASS = 1_u64 << 28
        Py_TPFLAGS_TYPE_SUBCLASS    = 1_u64 << 31
    {% else %}
        Py_TPFLAGS_LIST_SUBCLASS    = 1_u32 << 25
        Py_TPFLAGS_UNICODE_SUBCLASS = 1_u32 << 28
        Py_TPFLAGS_TYPE_SUBCLASS    = 1_u32 << 31
    {% end %}

    {% for name in %w|pyint pyfloat pytype pystring 
                              pystatic_m pynone types_m|%}
        @@{{name.id}} = uninitialized Void*
    {% end %}

    def self.init_pyhelper
        dict      = Python.PyEval_GetBuiltins # This is a bit unsafe
        @@pyint     = pydict_get1(dict,"int")
        @@pyfloat   = pydict_get1(dict,"float")
        @@pytype    = pydict_get1(dict,"type")
        @@pystring  = pydict_get1(dict,"str")
        @@pystatic_m = pydict_get1(dict,"staticmethod")
        @@pynone    = Python.Py_BuildValue("")
        @@types_m   = PyGC.get_tracked(lc_cast(pyimport("types","PyTypes"),LcClass).gc_ref)
    end

    macro pyobj_incref(obj)
        Python.Py_IncRef({{obj}})
    end
    
    macro pyobj_decref(obj)
        Python.Py_DecRef({{obj}})
    end

    # Errors

    macro py_fetch_error(ptype,value,btrace)
        Python.PyErr_Fetch({{ptype}},{{value}},{{btrace}})
    end

    macro py_restore_err(ptype,value,btrace)
        Python.PyErr_Restore({{ptype}},{{value}},{{btrace}})
    end

    macro pyerr_occurred
        Python.PyErr_Occurred 
    end

    macro pyerr_clear
        Python.PyErr_Clear 
    end

    # String

    macro string2py(string)
        Python.PyUnicode_DecodeFSDefault({{string}})
    end

    macro pystring2cstring(string)
        Python.PyUnicode_AsUTF8({{string}})
    end

    macro pystring2cstring2(string,size)
        Python.PyUnicode_AsUTF8AndSize({{string}},{{size}})
    end

    # Integers

    macro int2py(int)
        Python.PyLong_FromLong({{int}})
    end

    macro pyint2int(int)
        Python.PyLong_AsLong({{int}})
    end

    macro uint32_to_py(int)
        Python.PyLong_FromUnsignedLong({{int}})
    end

    macro uint64_to_py(int)
        Python.PyLong_FromUnsignedLongLong({{int}})
    end

    macro pyuint32_to_uint32(int)
        Python.PyLong_AsUnsignedLong({{int}})
    end

    macro pyuint64_to_uint64(int)
        Python.PyLong_AsUnsignedLongLong({{int}})
    end

    # Floats

    macro float2py(float)
        Python.PyFloat_FromDouble({{float}})
    end

    macro pyfloat2float(float)
        Python.PyFloat_AsDouble({{float}})
    end

    # Complex

    macro ccomplex2py(cpx)
        Python.PyComplex_FromCComplex({{cpx}})
    end

    macro pycomplex2c(cpx)
        Python.PyComplex_AsCComplex({{cpx}})
    end

    macro floats2pycomplex(re,im)
        Python.PyComplex_FromDoubles({{re}},{{im}})
    end

    # Object

    macro pyobj2pystr(obj)
        Python.PyObject_Str({{obj}})
    end

    macro pyobj_attr(obj,attr)
        Python. PyObject_GetAttrString({{obj}},{{attr}})
    end

    macro pyobj_attr2(obj,attr)
        Python. PyObject_GetAttr({{obj}},{{attr}})
    end

    macro pycall(call,args)
        Python.PyObject_CallObject({{call}},{{args}})
    end

    macro pytypeof(obj)
        Python.PyObject_Type({{obj}})
    end

    macro pytest(obj)
        Python.PyObject_IsTrue({{obj}})
    end

    macro pyobj_is_instance(obj,klass)
        Python.PyObject_IsInstance({{obj}},klass)
    end

    macro pyimport0(name)
        Python.PyImport_Import({{name}})
    end

    macro pyimport1(name,globals,locals,fromlist)
        Python.PyImport_ImportModuleEx({{name}},{{globals}},{{locals}},{{fromlist}})
    end

    macro get_pymodule_dict(mod)
        Python.PyModule_GetDict({{mod}})
    end

    # Tuple

    macro new_pytuple(size)
        Python.PyTuple_New({{size}})
    end

    macro set_pytuple_item(tuple,index,item)
        Python.PyTuple_SetItem({{tuple}},{{index}},{{item}})
    end

    macro pytuple_size(tuple)
        Python.PyTuple_Size({{tuple}})
    end

    macro pytuple_at_index(tuple,index)
        Python.PyTuple_GetItem({{tuple}},{{index}})
    end

    # Methods

    macro pyimethod_f(m)
        Python.PyInstanceMethod_Function({{m}})
    end

    macro pymethod_f(m)
        Python.PyMethod_Function({{m}})
    end

    macro pymethod_receiver(m)
        Python.PyMethod_Self({{m}})
    end

    macro py_cfunc_new(method,rec)
        Python.PyCFunction_New({{method}},{{rec}})
    end

    macro py_cfunc_new_ex(method,rec,mod)
        Python.PyCFunction_NewEx({{method}},{{rec}},{{mod}})
    end

    macro new_pymethod(func,rec)
        Python.PyMethod_New({{func}},{{rec}})
    end

    # Dicts

    macro pydict_get0(dict,name)
        Python.PyDict_GetItem({{dict}},{{name}})
    end

    macro pydict_get1(dict,name)
        Python.PyDict_GetItemString({{dict}},{{name}})
    end

    macro is_pysubtype(a,b)
        Python.PyType_IsSubtype({{a}},{{b}})
    end

    macro pytype_flags(t)
        Python.PyType_GetFlags({{t}})
    end

    # Lists
    
    macro pyary_new(size)
        Python.PyList_New({{size}})
    end

    macro pyary_set_item(ary,index,item)
        Python.PyList_SetItem({{ary}},{{index}},{{item}})
    end

    macro pyary_get_item(ary,index)
       Python.PyList_GetItem({{ary}},{{index}})
    end

    macro pyary_size(ary)
        Python.PyList_Size({{ary}})
    end

    # Slices
    macro pyslice_new(lft,rht)
        Python.PySlice_New({{lft}},{{rht}},nil)
    end


    # Checks

    @[AlwaysInline]
    def self.pytype_check(obj,type)
        t = pytypeof(obj)
        res = (t == type) || (is_pysubtype(t,type) == 1)
        pyobj_decref(t)
        return res
    end

    @[AlwaysInline]
    def self.pytype_fast_subclass(obj,f)
        t = pytypeof(obj)
        res = (pytype_flags(t) & f) != 0
        pyobj_decref(t)
        return res
    end
    
    macro is_pyfloat(obj)
        pytype_check({{obj}},@@pyfloat)
    end

    macro is_pyfloat_abs(obj)
        {{obj}} == @@pyfloat
    end

    macro is_pyint(obj)
        pytype_check({{obj}},@@pyint)
    end

    macro is_pyint_abs(obj)
        {{obj}} == @@pyint
    end

    macro is_pytype(obj)
        Internal.pytype_fast_subclass({{obj}},Internal::Py_TPFLAGS_TYPE_SUBCLASS)
    end

    @[AlwaysInline]
    def self.is_pytype_abs(obj)
        t = pytypeof(obj)
        res = t == @@pytype
        pyobj_decref(t)
        res
    end

    macro is_pystring(obj)
        Internal.pytype_fast_subclass({{obj}},Internal::Py_TPFLAGS_UNICODE_SUBCLASS)
    end

    @[AlwaysInline]
    def self.is_pystring_abs(obj)
        t = pytypeof(obj)
        res = t == @@pystring
        pyobj_decref(t)
        res
    end

    @[AlwaysInline]
    def self.is_pymodule(obj)
        m = Python.PyModule_New("dummy")
        t = pytypeof(m)
        pyobj_decref(m)
        res = pytype_check(obj,t)
        pyobj_decref(t)
        return res
    end

    macro is_pycallable(obj)
        Python.PyCallable_Check({{obj}}) == 1
    end

    macro is_pystatic_method(obj)
        pytype_check({{obj}},@@pystatic_m)
    end

    def self.is_pyfunction(obj : PyObject)
        funcType = pyobj_attr(@@types_m,"BuiltinFunctionType")
        if !funcType.null?
            res = pytype_check(obj,funcType)
            pyobj_decref(funcType)
            return res
        else 
            lc_warn("Unable to determine python function type. This may cause an error")
            return false 
        end
    end

    def self.is_pyimethod(obj)
        funcType = pyobj_attr(@@types_m,"MethodType")
        if !funcType.null?
            res = pytype_check(obj,funcType)
            pyobj_decref(funcType)
            return res
        else 
            lc_warn("Unable to determine python function type. This may cause an error")
            return false 
        end
    end

    def self.is_pyclass_method(obj : PyObject)
        res = !Python.PyMethod_Self(obj).null?
        pyerr_clear
        res
    end

    #macro is_pyimethod(obj)
    #    Python.PyInstanceMethod_Check({{obj}}) == 1
    #end

    macro is_pydict(obj)
        Python.PyDict_Check({{obj}}) == 1
    end

    macro is_pydict_abs(obj)
        Python.PyDict_CheckExact({{obj}}) == 1
    end

    macro is_pyary(obj)
       pytype_fast_subclass({{obj}},Py_TPFLAGS_LIST_SUBCLASS)
    end

end