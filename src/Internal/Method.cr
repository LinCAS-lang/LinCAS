
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


    private def self.lc_undef_method(name,owner : Structure)
        m       = LinCAS::LcMethod.new(name.as(String),FuncVisib::UNDEFINED)
        m.args  = nil
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

    def self.pymethod_new(name : String,pyobj : PyObject,owner : Structure? = nil,temp = true)
        m         = new_lc_method(name,FuncVisib::PUBLIC)
        m.type    = LcMethodT::PYTHON
        m.pyobj   = pyobj 
        m.arity   = -1 # get_pymethod_argc(pyobj,name)
        m.owner   = owner if owner
        return m
    end

    def self.pystatic_method_new(name : String,pyobj : PyObject,owner : Structure? = nil,temp = false)
        m        = pymethod_new(name,pyobj,owner,temp)
        m.static = true
        return m 
    end

    def self.lc_def_method(name : String, args : Array(FuncArgument),
                           arity : Intnum, code : Bytecode, visib : FuncVisib = FuncVisib::PUBLIC)
        m         = new_lc_method(name,visib)
        m.type    = LcMethodT::USER
        m.args    = args 
        m.code    = code 
        m.arity   = arity
        return m
    end

    def self.lc_def_static_method(name : String, args : Array(FuncArgument), 
                                  arity : Intnum,code : Bytecode,visib : FuncVisib = FuncVisib::PUBLIC)
        m        = lc_def_method(name,args,arity,code,visib)
        m.static = true
        return m 
    end

    def self.lc_define_internal_method(name, owner : LinCAS::Structure, code, arity : Intnum)
        m          = new_lc_method(name, FuncVisib::PUBLIC)
        set_default(m,owner,code,arity)
        return m
    end

    def self.lc_define_protected_internal_method(name : String, owner : Structure, code, arity)
        m = new_lc_method(name,FuncVisib::PROTECTED)
        set_default(m,owner,code,arity)
        return m
    end

    def self.lc_define_internal_static_method(name, owner : LinCAS::Structure, code, arity)
        m        = self.lc_define_internal_method(name,owner,code,arity)
        m.static = true
        return m
    end

    def self.lc_undef_usr_method(name,owner : Structure)
        return lc_undef_method(name,owner)
    end

    def self.lc_undef_usr_static_method(name,owner : Structure)
        m = lc_undef_usr_method(name,owner)
        m.static = true 
        return m 
    end

    def self.lc_undef_internal_method(name,owner : LinCAS::Structure)
        m = lc_undef_method(name,owner)
        m.type = LcMethodT::INTERNAL 
        return m
    end 

    def self.lc_undef_internal_static(name,owner : Structure)
        m = lc_undef_internal_method(name,owner)
        m.static = true 
        return m
    end

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

    macro undef_static(name,owner)
        internal.lc_undef_internal_static({{name}},{{owner}})
    end 


    def self.seek_method(receiver : Structure, name,protctd = false)
        method = seek_instance_method(receiver,name,!protctd)
        return 0 if method == 3
        if method != 0
            return method 
        else 
            parent = parent_of(receiver) 
            while parent 
                method = seek_instance_method(parent,name,true,protctd)
                return 0 if method == 3
                return method if method != 0
                parent = parent_of(parent)
            end
        end
        return method
    end

    def self.seek_instance_method(receiver : Structure,name,check = true,protctd = false)
        if is_pyembedded(receiver)
            return seek_instance_method_emb(receiver,name)
        end
        method = receiver.methods.as(SymTab).lookUp(name)
        if method.is_a? LcMethod
            return 3 if method.visib == FuncVisib::UNDEFINED
            return method unless check
            method = method.as(LcMethod)
            case method.visib 
                when FuncVisib::PUBLIC
                    return method
                when FuncVisib::PROTECTED
                    return method if protctd
                    return 1
                when FuncVisib::PRIVATE 
                    return 2
                when FuncVisib::UNDEFINED 
                    return 3
            end
        else
            return 0
        end
    end

    def self.seek_static_method(receiver : Structure, name)
        method    = seek_static_method2(receiver,name)
        return 0 if method == 1
        if method.is_a? LcMethod
            return method
        else
            parent = parent_of(receiver)
            while parent 
                method = seek_static_method2(parent,name)
                return 0 if method == 1
                return method if method.is_a? LcMethod
                parent = parent_of(parent) 
            end
        end
        return 0
    end
    
    def self.seek_static_method2(receiver : Structure, name : String)
        if is_pyembedded(receiver)
            return seek_static_method_emb(receiver,name)
        end
        method = receiver.statics.as(SymTab).lookUp(name)
        if !method.nil?
            method = method.as(LcMethod)
            return 1 if method.visib == FuncVisib::UNDEFINED
            return method
        else
            return 0
        end
    end

    def self.seek_instance_method_emb(receiver : Structure, name : String)
        method = receiver.methods.as(HybridSymT).lookUp(name)
        if method == nil
            return 0
        elsif method.is_a? LcMethod
            return 1 if method.visib == FuncVisib::UNDEFINED
            return method
        elsif method.is_a? PyObject
            if method.null?
                pyerr_clear
                return 0 
            end
            if is_pycallable(method) && !is_pytype_abs(method) && 
                                     !is_pystatic_method(method) && !is_pyclass_method(method)
                return pymethod_new(name,method,receiver)
            else
                pyobj_decref(method)
                return 0
            end
        else
            lc_bug("Invalid method type received")
            return 0
        end
    end

    def self.seek_static_method_emb(receiver : Structure, name : String)
        method = receiver.statics.as(HybridSymT).lookUp(name)
        if method == nil
            return 0
        elsif method.is_a? LcMethod
            return 1 if method.visib == FuncVisib::UNDEFINED
            return method
        elsif method.is_a? PyObject
            if method.null?
                pyerr_clear
                return 0 
            end
            if is_pycallable(method) && !is_pytype(method) &&
                    (is_pyclass_method(method) || !is_pyimethod(method))
                return pystatic_method_new(name,method,receiver)
            else
                pyobj_decref(method)
                return 0
            end
        else
            lc_bug("Invalid method type received")
            return 0
        end
    end

    def self.lc_obj_responds_to?(obj : Value,method : String,default = true)
        if obj.is_a? Structure && default
            m = internal.seek_static_method(obj.as(Structure),method)
        else 
            if obj.is_a? Structure 
                klass = obj 
            else 
                klass = class_of(obj)
            end
            m = internal.seek_method(klass.as(Structure),method)
        end
        return m.is_a? LcMethod
    end

    def self.lc_obj_has_internal_m?(obj : Value,name : String)
        if obj.is_a? Structure
            method = seek_static_method(obj,name)
        else
            method = seek_instance_method(class_of(obj),name)
        end 
        return -1 unless method.is_a? LcMethod
        return 0 if method.type == LcMethodT::INTERNAL 
        return 1
    end


    ##################

    LC_METHOD_CALLER = ->(_self_ : PyObject,argv : PyObject) {
        {% if flag?(:x86_64) %}
            addr = pyuint64_to_py(_self_)
        {% else %}
            addr = pyuint32_to_py(_self_)
        {% end %}
        method = addr.as(Method)
        args   = pytuple2ary(argv)
        val    = Exec.call_method(method,args)
        return obj2py(val)
    }

    class Method < BaseC
        @method   = uninitialized LcMethod
        @receiver = uninitialized Value
        property method,receiver
    end

    class UnboundMethod
        @method   = uninitialized LcMethod
        property method
    end

    macro method_get_receiver(method)
        lc_cast({{method}},Method).receiver 
    end

    private def self.method_new
        m = Method.new
        m.klass = MClass
        m.data  = MClass.data.clone 
        m.id    = m.object_id 
        return m
    end

    private def self.unbound_method_new
        m = UnboundMethod.new
        m.klass = UnboundM
        m.data  = UnboundM.data.clone 
        m.id    = m.object_id 
        return m
    end

    def self.build_method(receiver : Value,method : LcMethod)
        method          = method_new
        method.receiver = receiver
        method.method   = method 
        return method 
    end

    def self.build_unbound_method(method : LcMethod)
        method          = unbound_method_new
        method.method   = method 
        return method 
    end

    def self.lc_method_call(method : Value, args : An)
    
    end

    def self.lc_method_to_proc(method : Value)

    end

    def self.lc_method_receiver(method : Value)
        return method_get_receiver(method)
    end

    def self.lc_method_to_py(method : Value)
        addr = method.as(Void*).address
        {% if flag?(:x86_64) %}
            pyint = uint64_to_py(addr)
        {% else %}
            pyint = uint32_to_py(addr)
        {% end %}
        m = define_pymethod(method.name,LC_METHOD_CALLER,pyint,METH_VARARGS)
        pyobj_decref(pyint)
        return m
    end

    MClass = lc_build_internal_class("Method")
    lc_undef_allocator(MClass)



    UnboundM = lc_build_internal_class("UnboundMethod")
    lc_undef_allocator(UnboundM)


end
