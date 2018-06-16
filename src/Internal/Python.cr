
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
    #Types          = pyimport("types")

    macro check_pyerror(ptr)
        if {{ptr}}.null? || pyerr_occurred
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
    def self.pyobj_decref_n(*obj)
        obj.each do |item|
            pyobj_decref(item)
        end
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

    private def self.pyimport(name : String,import_name : String)
        p_name = string2py(name)
        check_pyerror(p_name)
        p_module = pyimport0(p_name)
        pyobj_decref(p_name)
        if !p_module.null?
            if is_pymodule(p_module)
                import = lc_build_pymodule(import_name,p_module)
            elsif is_pytype(p_module)
                import = lc_build_pyclass(import_name,p_module)
            else
                lc_raise(LcPyImportError,"Invalid import object")
                pyobj_decref(p_module)
                import = Null
            end
            return import
        else
            pyobj_decref(p_module)
            lc_raise_py_error
            return Null
        end
    end

    def self.lc_pyimport(name : Value, import_name : Value)
        name = id2string(name)
        return Null unless name
        import_name = id2string(import_name)
        return Null unless import_name
        return pyimport(name,import_name)
    end

    py_import = LcProc.new do |args|
        args = lc_cast(args,T3)
        next lc_pyimport(args[1],args[2])
    end


    PyModule = lc_build_internal_module("Python")
    
    lc_module_add_internal(PyModule,"pyimport",py_import,   2)
    
end