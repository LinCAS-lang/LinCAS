
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

    class LcPyObject < LcBase
        @pyObj  = PyObject.null
        @gc_ref : PyGC::Ref? = nil
        property pyObj,gc_ref

        def initialize(@pyObj : PyObject)
        end

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
         is_pystring({{obj}})||
         is_pyary({{obj}}))
    end

    macro pyobj_check(obj)
       if !(obj.is_a? LcPyObject)
          lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof({{obj}})} into PyObject")
          return Null 
       end
    end

    macro binary_op(args,op)
        {{args}} = lc_cast({{args}},T2)
        _self_   = args[0]
        obj      = args[1]
        next Exec.lc_call_fun(_self_,{{op}},obj)
    end

    private def self.pyobj_convert(obj : PyObject)
        if is_pyint(obj)
            tmp = num2int(pyint2int(obj))
        elsif is_pyfloat(obj)
            tmp = num2float(pyfloat2float(obj))
        elsif is_pystring(obj)
            tmp = pystring_to_s(obj)
        elsif is_pyary(obj)
            tmp = pyary2ary(obj)
        elsif obj == @@pynone
            tmp = Null
        else
            lc_bug("Python object converter called on a wrong object")
            tmp = Null
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
    # converting the type directly or wrapping it into other structures
    def self.pyobj2lc(obj : PyObject, borrowed_ref = false)
        if pyobj_converted? obj 
            return pyobj_convert(obj)
        else
            pyobj_incref(obj) if borrowed_ref
            return build_pyobj(obj)
        end
    end


    # This function wraps Python objects in LinCAS objects
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
            return pytype ? lc_build_unregistered_pyclass(name,obj,@@lc_pyobject) : 
                                lc_build_unregistered_pymodule(name,obj)
        end
        gcref = PyGC.track(obj)
        type  = pytypeof(obj)
        name  = pytype2string(type)
        klass = lc_build_unregistered_pyclass(name,type,@@lc_pyobject)
        obj   =  build_pyobj(klass,obj)
        pyobj_set_gcref(obj,gcref)
        return obj
    end

    def self.build_pyobj(klass : LcClass,obj : PyObject)
        # pyobj = LcPyObject.new 
        pyobj    = lincas_obj_alloc(LcPyObject, klass, obj)
        pyobj.id = pyobj.object_id
        return pyobj.as( LcVal)
    end

    # This function performs the first step of an instance of 
    # a Python object given a class. No check is performed to verify if
    # the klass is a Python class (wrapped in a LinCAS one)
    def self.build_pyobj(klass :  LcVal)
        klass = lc_cast(klass,LcClass)
        objk  = klass.namespace.py_obj.not_nil!
        return build_pyobj(klass,objk)
    end

    def self.lc_pyobj_init(obj :  LcVal,args : LcVal)
        args = args.as(Ary)
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
            return lc_cast(pyobj_convert(value), LcVal)
        else
            gcref = PyGC.track(value)
            pyobj_set_gcref(obj,gcref)
            pyobj_set_obj(obj,value)
            return obj
        end
    end

    def self.lc_pyobj_to_s(obj :  LcVal)
        return lc_obj_to_s(obj) unless obj.is_a? LcPyObject
        pyObj = pyobj_get_obj(obj)
        str = pyobj2pystr(pyObj)
        check_pyerror(str)
        tmp = pystring_to_s(str)
        pyobj_decref(str)
        return tmp
    end

    def self.lc_pyobject_call(obj :  LcVal,argv : LcVal)
        argv = argv.as(Ary)
        pyobj_check(obj)
        name   = id2string(argv[0])
        argv   = argv.shifted_copy
        return Null unless name
        method = seek_method(obj.klass, name, explicit: true)
        if method.is_a? LcMethod && method.type == LcMethodT::PYTHON
            return lc_call_python(method,argv)
        else
            lc_raise(lc_nomet_err,"Undefined method `#{name}' for #{pyobj2string(pyobj_get_obj(obj))} : PyObject")
            return Null 
        end
    end

    {% for name in %w|sum sub mul div pow| %}
        @[AlwaysInline]
        def self.lc_pyobj_{{name.id}}(v1 : LcVal,v2 : LcVal)
            return Exec.lc_call_fun(v1,"__{{name.id}}__",v2)
        end
    {% end %}

    @[AlwaysInline]
    def self.lc_pyobj_at_index(obj : LcVal,index : LcVal)
        return Exec.lc_call_fun(obj,"__getitem__",index)
    end

    @[AlwaysInline]
    def self.lc_pyobj_set_index(obj :  LcVal, index :  LcVal, item :  LcVal)
        return Exec.lc_call_fun(obj,"__setitem__",index,item)
    end


    def self.init_pyobject
        @@lc_pyobject = lc_build_internal_class("PyObject",@@lc_object)
        define_allocator(@@lc_pyobject,lc_obj_allocate)

        add_method(@@lc_pyobject,"init",lc_pyobj_init,         -1)
        add_method(@@lc_pyobject,"to_s",lc_pyobj_to_s,          0)
        add_method(@@lc_pyobject,"pycall",lc_pyobject_call,    -2)
        add_method(@@lc_pyobject,"+",lc_pyobj_sum,              1)
        add_method(@@lc_pyobject,"-",lc_pyobj_sub,              1)
        add_method(@@lc_pyobject,"*",lc_pyobj_mul,              1)
        add_method(@@lc_pyobject,"/",lc_pyobj_div,              1)
        add_method(@@lc_pyobject,"**",lc_pyobj_pow,             1)
        add_method(@@lc_pyobject,"[]",lc_pyobj_at_index,        1)
        add_method(@@lc_pyobject,"[]=",lc_pyobj_set_index,      2)
    end


end