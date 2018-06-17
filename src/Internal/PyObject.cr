
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

    class LcPyObject < BaseC
        @pyObj  = PyObject.null
        @gc_ref : IntnumR = -1
        property pyObj,gc_ref
        def finalize
            PyGC.dispose(@gc_ref)
        end
    end

    macro pyobj_get_obj(obj)
        lc_cast({{obj}},LcPyObject).pyObj
    end

    macro pyobj_set_obj(obj,pyobj)
        lc_cast({{obj}},LcPyObject).pyObj = {{pyobj}}
    end

    macro pyobj_set_gcref(obj,gcref)
        lc_cast({{obj}},LcPyObject).gc_ref = {{gcref}}
    end

    macro pyobj_converted?(obj)
        (is_pyint({{obj}})   || 
         is_pyfloat({{obj}}) || 
         is_pystring({{obj}}))
    end

    pyobj_allocator = LcProc.new do |args|
        next lc_obj_allocate(PyObjClass)
    end

    private def self.pyobj_convert(obj : PyObject)
        if is_pyint(obj)
            tmp = num2int(pyint2int(obj))
        elsif is_pyfloat(obj)
            tmp = num2float(pyfloat2float(obj))
        elsif is_pystring(obj)
            tmp = pystring_to_s(obj)
        else
            lc_bug("Python object converter called on a wrong object")
            tmp = PyObject.null
        end
        pyobj_decref(obj)
        return tmp
    end

    private def self.pyobj2string(obj : PyObject)
        obj = pyobj2pystr(obj)
        str = pystring2cstring2(obj,out size)
        pyobj_decref(obj)
        return String.new(str.to_slice(size))
    end

    private def self.pytype2string(obj : PyObject)
        lc_bug("Expected python class or module") unless is_pytype(obj) || is_pymodule(obj)
        name    = pyobj_attr(obj,"__name__")
        strname = pystring2cstring2(name,out size)
        pyobj_decref(name)
        return String.new(strname.to_slice(size))
    end

    # This function converts a Python object into a LinCAS one,
    # converting the type directly or wrapping in into other structures
    def self.pyobj2lc(obj : PyObject)
        if pyobj_converted? obj 
            return pyobj_convert(obj)
        else
            return build_pyobj(obj)
        end
    end


    # This function wraps Python objects in LinCAS obiects
    # and it must be used on objects returned by python functions
    # or pyDicts which can't be converted in LinCAS objects or wrapped
    # as classes or modules. 
    # It is recommended to use `pyobj2lc` instead, which also includes
    # a call to `build_pyobj`
    #
    # This function tracks python objects for GC 
    @[AlwaysInline]
    def self.build_pyobj(obj : PyObject)
        pytype = is_pytype(obj)

        # python classes and modules are already tracked by their LinCAS builders,
        # so there is no need to call PyGC.track
        if pytype || is_pymodule(obj)
            name = pytype2string(obj)
            return pytype ? lc_build_unregistered_pyclass(name,obj,PyObjClass) : 
                                lc_build_unregistered_pymodule(name,obj)
        end
        gcref = PyGC.track(obj)
        obj   =  build_pyobj(PyObjClass,obj)
        pyobj_set_gcref(obj,gcref)
        return obj
    end

    def self.build_pyobj(klass : LcClass,obj : PyObject)
        pyobj = LcPyObject.new 
        pyobj_set_obj(pyobj,obj)
        pyobj.klass = klass 
        pyobj.data  = klass.data.clone 
        pyobj.id    = pyobj.object_id
        return pyobj
    end

    def self.build_pyobj(klass : Value)
        klass = lc_cast(klass,LcClass)
        objk  = klass.symTab.as(HybridSymT).pyObj
        return build_pyobj(klass,objk)
    end

    def self.lc_pyobj_init(obj : Value,args : An)
        return obj unless obj.is_a? LcPyObject
        klass = pyobj_get_obj(obj)
        if !is_pytype(klass) && klass.is_a? PyObject
            return obj 
        end
        args  = prepare_pycall_args(args)
        check_pyerror(args)
        value = pycall(klass,args)
        check_pyerror(value)
        if pyobj_converted? value
            return lc_cast(pyobj_convert(value),Value)
        else
            gcref = PyGC.track(value)
            pyobj_set_gcref(obj,gcref)
            pyobj_set_obj(obj,value)
            return obj
        end
    end

    pyobj_init = LcProc.new do |args|
        args = lc_cast(args,An)
        next lc_pyobj_init(args.shift,args)
    end

    def self.lc_pyobj_to_s(obj : Value)
        return lc_obj_to_s(obj) unless obj.is_a? LcPyObject
        pyObj = pyobj_get_obj(obj)
        str = pyobj2pystr(pyObj)
        check_pyerror(str)
        tmp = pystring_to_s(str)
        pyobj_decref(str)
        return tmp
    end

    pyobj_to_s = LcProc.new do |args|
        next lc_pyobj_to_s(*lc_cast(args,T1))
    end


    PyObjClass = lc_build_internal_class("PyObject",Obj)
    lc_set_allocator(PyObjClass,pyobj_allocator)

    lc_add_internal(PyObjClass,"init",pyobj_init,           -1)
    lc_add_internal(PyObjClass,"to_s",pyobj_to_s,            0)


end