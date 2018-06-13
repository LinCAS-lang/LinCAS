
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

    private def self.get_pymethod_argc(method : PyObject,name : String)
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
        lc_warn("Unable to get the number of arguments of python method #{name}. This may cause an exception")
        return 1
    end

    private def self.prepare_pycall_args(argv : Array(Value),argc : IntnumR,static = false)
        lc_bug("Unhandled argument missmatch") if argv.size < argc
        pytuple = new_pytuple(argc)
        sub     = static ? 1 : 0
        (argc + sub).times do |i|
            tmp = obj2py(argv[i])
            if !tmp 
                pyobj_decref(pytuple)
                return PyObject.null 
            end
            set_pytuple_item(pytuple,i-sub,tmp)
        end
        return pytuple
    end

    def self.lc_call_python(method : LcMethod, argv : Array(Value))
        pym    = lc_cast(method.pyobj,PyObject) 
        lc_bug("Python method not set") if pym.null?
        argc   = method.arity
        if method.static
            pyargs = prepare_pycall_args(argv,argc)
        else
            pyargs = prepare_pycall_args(argv,argc) 
        end
        return Null if pyargs.null?
        result = pycall(pym,pyargs)
        pyobj_decref(pyargs)
        pyobj_decref(pym) if method.needs_gc
        check_pyerror(result)
        return pyobj2lc(result)
    end

end