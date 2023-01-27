
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


    private def self.lc_undef_method(name,owner : LcClass)
        m       = LinCAS::LcMethod.new(name.as(String),FuncVisib::UNDEFINED)
        m.code  = nil
        m.arity = 0
        m.owner = owner
        return m
    end

    macro new_lc_method(name,visib)
        LcMethod.new({{name}},{{visib}})
    end

    macro set_default(m,owner,code,arity)
        {{m}}.type     = LcMethodT::INTERNAL
        {{m}}.owner    = {{owner}}
        {{m}}.code     = {{code}}
        {{m}}.arity    = {{arity}}
    end 

    macro is_pyembedded(strucure)
        ({{strucure}}.type == SType::PyMODULE) || 
             ({{strucure}}.type == SType::PyCLASS)
    end

    def self.pymethod_new(name : String,pyobj : PyObject,owner : LcClass? = nil,temp = true)
        m         = new_lc_method(name,FuncVisib::PUBLIC)
        m.type    = LcMethodT::PYTHON
        m.pyobj   = pyobj 
        m.arity   = -1 # get_pymethod_argc(pyobj,name)
        m.owner   = owner if owner
        return m
    end

    def self.pystatic_method_new(name : String,pyobj : PyObject,owner : LcClass? = nil,temp = false)
        m        = pymethod_new(name,pyobj,owner,temp)
        m.static = true
        return m 
    end

    def self.lc_def_method(name : String, args : FuncArgSet,
                           arity : Intnum, code : Bytecode, visib : FuncVisib = FuncVisib::PUBLIC)
        m         = new_lc_method(name,visib)
        m.type    = LcMethodT::USER
        m.args    = args 
        m.code    = code 
        m.arity   = arity
        return m
    end

    def self.lc_def_static_method(name : String, args : FuncArgSet, 
                                  arity : Intnum,code : Bytecode,visib : FuncVisib = FuncVisib::PUBLIC)
        m        = lc_def_method(name,args,arity,code,visib)
        m.static = true
        return m 
    end

    def self.lc_define_internal_method(name, owner : LinCAS::LcClass, code, arity : Intnum)
        m          = new_lc_method(name, FuncVisib::PUBLIC)
        set_default(m,owner,code,arity)
        return m
    end

    def self.lc_define_protected_internal_method(name : String, owner : LcClass, code, arity)
        m = new_lc_method(name,FuncVisib::PROTECTED)
        set_default(m,owner,code,arity)
        return m
    end

    def self.lc_define_internal_static_method(name, owner : LinCAS::LcClass, code, arity)
        m        = self.lc_define_internal_method(name,owner,code,arity)
        m.static = true
        return m
    end

    def self.lc_undef_usr_method(name,owner : LcClass)
        return lc_undef_method(name,owner)
    end

    # def self.lc_undef_usr_static_method(name,owner : LcClass)
    #     m = lc_undef_usr_method(name,owner)
    #     m.static = true 
    #     return m 
    # end

    def self.lc_undef_internal_method(name,owner : LinCAS::LcClass)
        m = lc_undef_method(name,owner)
        m.type = LcMethodT::INTERNAL 
        return m
    end 

    # def self.lc_undef_internal_static(name,owner : LcClass)
    #     m = lc_undef_internal_method(name,owner)
    #     m.static = true 
    #     return m
    # end

    macro define_method(name,owner,code,arity)
        internal.lc_define_internal_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro define_protected_method(name,owner,code,arity)
        internal.lc_define_protected_internal_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro undef_method(name,owner)
        internal.lc_undef_internal_method({{name}},{{owner}})
    end 

    macro define_static(name,owner,code,arity)
        internal.lc_define_internal_static_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    # macro undef_static(name,owner)
    #     internal.lc_undef_internal_static({{name}},{{owner}})
    # end 

    def self.seek_method(receiver : LcClass, name : String, explicit : Bool, ignore_visib = false)
        klass = receiver
        i = 0
        # when reason = 0 -> undefined
        # when reason = 1 -> protected method called
        # when reason = 2 -> private method called
        m_missing_reason = 0
        while klass && (i += 1)
            method = klass.methods.find(name)
            if method
                if method.is_a? PyObject # TO Fix
                    if method.null?
                      pyerr_clear
                      method = nil
                      m_missing_reason = 0 
                    elsif type_of(receiver).metaclass? && is_pycallable(method) && !is_pytype(method) &&
                        (is_pyclass_method(method) || !is_pyimethod(method))
                        method = pystatic_method_new(name,method,receiver)
                    else
                        pyobj_decref(method)
                        m_missing_reason = 0
                    end
                else
                    case method.visib
                    when FuncVisib::PROTECTED
                        method = ignore_visib ? method : (!explicit ? method : nil)
                        m_missing_reason = 1
                    when FuncVisib::PRIVATE 
                        method = ignore_visib ? method : ((!explicit && i == 1) ? method : nil)
                        m_missing_reason = 2
                    when FuncVisib::UNDEFINED 
                        method = nil 
                        m_missing_reason = 0
                    end 
                end
                break
            end
            klass = klass.parent
        end
        return VM::CallCache.new(method, m_missing_reason)
    end

    def self.lc_obj_responds_to?(obj :  LcVal, name : String)
        m = internal.seek_method(obj.klass, name, true) # Method call is of explicit type
        return m.is_a? LcMethod
    end

    def self.lc_obj_has_internal_m?(obj :  LcVal,name : String)
        cc = internal.seek_method(obj.klass, name, explicit: false, ignore_visib: true)
        return -1 unless cc.method
        return 0 if cc.method.not_nil!.type == LcMethodT::INTERNAL 
        return 1
    end


    ##################

    LC_METHOD_CALLER = ->(_self_ : PyObject,argv : PyObject) {
        {% begin %}
        {% if flag?(:x86_64) %}
            addr = pyuint64_to_uint64(_self_)
        {% else %}
            addr = pyuint32_to_uint32(_self_)
        {% end %}
        method = Pointer(Void).new(addr).as(Method)
        args   = pytuple2ary(argv)
        if args
            val = Exec.call_method(method,args)
            obj = obj2py(val)
            if obj
                pyobj_incref(obj)
                return obj  
            end
        end
        return_pynone
        {% end %}
    }


    class Method < LcVal
        @method   = uninitialized LcMethod
        @receiver = uninitialized  LcVal
        @pym_def  = Pointer(Python::PyMethodDef).null
        property method,receiver,pym_def
    end

    class UnboundMethod < LcVal
        @method   = uninitialized LcMethod
        property method
    end

    macro method_get_receiver(method)
        lc_cast({{method}},Method).receiver 
    end

    macro method_pym_def(m)
        {{m}}.as(Method).pym_def
    end

    macro set_method_pym_def(m,d)
        {{m}}.as(Method).pym_def = {{d}}
    end

    private def self.method_new
        return lincas_obj_alloc(Method, @@lc_method)
    end

    private def self.unbound_method_new
        return lincas_obj_alloc(UnboundMethod, @@lc_unbound_method)
    end

    def self.build_method(receiver :  LcVal,method : LcMethod)
        m          = method_new
        m.receiver = receiver
        m.method   = method 
        return m
    end

    def self.build_unbound_method(method : LcMethod)
        m        = unbound_method_new
        m.method = method 
        return m 
    end

    @[AlwaysInline]
    def self.lc_method_call(method :  LcVal, argv :  LcVal)
        argv = argv.as Ary
        return Exec.call_method(lc_cast(method,Method),argv)
    end

    def self.lc_method_to_proc(method :  LcVal)

    end

    @[AlwaysInline]
    def self.lc_method_receiver(method :  LcVal)
        return method_get_receiver(method)
    end

    @[AlwaysInline]
    def self.lc_method_name(m : LcVal)
        m = m.as(Method).method
        return build_string(m.name)
    end

    @[AlwaysInline]
    def self.lc_method_owner(m : LcVal)
        m = m.as(Method).method
        return m.owner || Null
    end

    def self.method_to_py(method :  LcVal)
        {% begin %}
        addr = method.as(Void*).address
        {% if flag?(:x86_64) %}
            pyint = uint64_to_py(addr)
        {% else %}
            pyint = uint32_to_py(addr)
        {% end %}
        m = define_pymethod(method,LC_METHOD_CALLER,pyint,METH_VARARGS)
        pyobj_decref(pyint)
        return m
        {% end %}
    end

    def self.init_method
        @@lc_method = lc_build_internal_class("Method")
        lc_undef_allocator(@@lc_method)

        add_method(@@lc_method,"call",lc_method_call,               -1)
        add_method(@@lc_method,"receiver",lc_method_receiver,        0)
        add_method(@@lc_method,"name",lc_method_name,                0)
        add_method(@@lc_method,"owner",lc_method_owner,                             0)

    end

    def self.init_unbound_method
        @@lc_unbound_method = lc_build_internal_class("UnboundMethod")
        lc_undef_allocator(@@lc_unbound_method)
    end


end
