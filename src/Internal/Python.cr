
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

module LinCAS::Internal

    alias PyObject = Python::PyObject
    PYPATTERN      = /'.+'/
    PyREGISTER     = Hash(String,PyObject).new

    macro check_pyerror(ptr)
        if {{ptr}}.null? 
            lc_raise_py_error
            return Null 
        end
    end

    @[AlwaysInline]
    def self.pyinit
        Python.Py_Initialize
    end

    @[AlwaysInline]
    def self.pyfinalize
        Python.Py_Finalize 
    end

    @[AlwaysInline]
    def self.py_decref_n(*obj)
        obj.each do |item|
            pyobj_decref(item)
        end
    end

    def self.py_dispose
        PyREGISTER.each_value do |v|
            pyobj_decref(v)
        end
    end

    private def self.pyobj2string(obj : PyObject)
        obj = pyobj2pystr(obj)
        str = pystring2cstring2(obj,out size)
        pyobj_decref(obj)
        return String.new(str.to_slice(size))
    end

    @[AlwaysInline]
    private def self.exception_name(str : String)
        tmp = str.scan(PYPATTERN)
        if tmp.size == 0
            return ""
        else
            tmp = tmp[0][0]?
            return tmp if tmp 
            return ""
        end
    end

    def self.lc_raise_py_error
        type = PyObject.null 
        val  = PyObject.null 
        tr   = PyObject.null 
        py_fetch_error(pointerof(type),pointerof(val),pointerof(tr))
        type_ = pyobj2string(type)
        val_  = pyobj2string(val)
        return lc_raise(LcPyException," #{exception_name(type_)}: #{val_}")
        pyobj_decref_n(type,val,tr)
    end

    def self.pyobj2lc(obj : PyObject)
        if is_pyint(obj)
            return num2int(pyint2int(obj))
        elsif is_pyfloat(obj)
            return num2float(pyfloat2float(obj))
        end
    end


    private def self.pyimport(name : String)
        if PyREGISTER.has_key? name
            return fetch_pystruct(name)
        end
        p_name = string2py(name)
        check_pyerror(p_name)
        p_module = pyimport0(p_name)
        pyobj_decref(p_name)
        if !p_module.null?
            if is_pymodule(p_module)
                return lc_build_pymodule(name,p_module)
            elsif is_pytype(p_module)
                return lc_build_pyclass(name,p_module)
            else
                lc_raise(LcPyImportError,"Invalid import object")
                pyobj_decref(p_module)
                return Null
            end
        else
            pyobj_decref(p_module)
            lc_raise_py_error
            return Null
        end
    end

    def self.lc_pyimport(name : Value)
        name = id2string(name)
        return lcfalse unless name
        return pyimport(name)
    end

    py_import = LcProc.new do |args|
        next lc_pyimport(lc_cast(args,T2)[1])
    end


    PyModule = lc_build_internal_module("Python")
    
    lc_module_add_internal(PyModule,"pyimport",py_import,   1)
    
end