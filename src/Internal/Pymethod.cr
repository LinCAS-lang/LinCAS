
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

    METH_VARARGS  = 0x0001
    METH_KEYWORDS = 0x0002
    METH_NOARGS   = 0x0004
    METH_O        = 0x0008
    METH_CLASS    = 0x0010
    METH_STATIC   = 0x0020

    private def self.get_pymethod_argc(method : PyObject,name : String? = nil)
        f_code = pyobj_attr(method,"__code__")
        if !f_code.null?
            argc = pyobj_attr(f_code,"co_argcount")
            pyobj_decref(f_code)
            if ! argc.null?
                res = pyint2int(argc)
                pyobj_decref(argc)
                return res 
            end
        end
        pyerr_clear

        return -1
    end

    private def self.prepare_pycall_args(argv : Ary,static = false)
        sub     = static ? 1 : 0
        argc    = argv.size
        pytuple = new_pytuple(argc-sub)
        (argc - sub).times do |i|
            tmp = obj2py(argv[i + sub],ref: true)
            if !tmp 
                pyobj_decref(pytuple)
                return PyObject.null 
            end
            set_pytuple_item(pytuple,i,tmp)
        end
        return pytuple
    end

    def self.lc_call_python(method : LcMethod, argv : Ary)
        pym    = lc_cast(method.pyobj,PyObject) 
        lc_bug("Python method not set") if pym.null?
        if method.static
            pyargs = prepare_pycall_args(argv,true)
        else
            pyargs = prepare_pycall_args(argv) 
        end
        return Null if pyargs.null?
        result = pycall(pym,pyargs)
        pyobj_decref(pyargs)
        pyobj_decref(pym) if method.needs_gc
        check_pyerror(result)
        return pyobj2lc(result)
    end

    def self.lc_seek_instance_pymethod(obj :  LcVal, name : String)
        lc_bug("Expected LcPyObject (#{obj.class} received)") unless obj.is_a? LcPyObject
        pyobj  = pyobj_get_obj(obj)
        method = pyobj_attr(pyobj,name)
        if method.null?
            pyerr_clear
            return nil 
        end
        if is_pyimethod(method) && is_pycallable(method) && !is_pytype_abs(method)
            return pymethod_new(name,method,obj.klass)
        else
            pyobj_decref(method)
            return nil
        end 
    end

    def self.new_pymethod_def(name : String, function : Void*, flags : LibC::Int)
        m             = Pointer(Python::PyMethodDef).malloc
        m.value.name  = name.to_unsafe
        m.value.func  = function
        m.value.flags = flags
        m.value.doc   = nil
        return m
    end

    @[AlwaysInline]
    def self.define_pymethod(method :  LcVal,func : Proc, _self_ : PyObject, flags : LibC::Int)
        if (pym_def = method_pym_def(method)).null?
            pym_def = new_pymethod_def(lc_cast(method,Method).method.name, func.pointer, flags)
            set_method_pym_def(method,pym_def)
        end
        return py_cfunc_new(pym_def,_self_)
    end

end