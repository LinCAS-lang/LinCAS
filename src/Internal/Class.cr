
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

    macro parent_of(klass)
       {{klass}}.as(LcClass).parent
    end

    macro class_of(obj)
        {{obj}}.klass 
    end

    macro path_of(obj)
        {{obj}}.as(Structure).path 
    end

    macro type_of(obj)
        {{obj}}.as(Structure).type
    end

    macro class_name(klass)
        {{klass}}.as(LcClass).name 
    end

    macro check_pystructs(scp,str)
        if {{str}}.is_a? Structure && 
            ({{str}}.type == SType::PyCLASS || {{str}}.type == SType::PyMODULE) &&
                                            ({{str}}.flags & ObjectFlags::REG_CLASS == 0)
            {{str}}.symTab.parent = {{scp}}.symTab
            {{scp}}.symTab.addEntry({{str}}.name,{{str}})
            {{str}}.flags |= ObjectFlags::REG_CLASS
        end
    end

    macro check_pystructs2(symTab,str)
        if {{str}}.is_a? Structure && 
            ({{str}}.type == SType::PyCLASS || {{str}}.type == SType::PyMODULE) &&
                                            ({{str}}.flags & ObjectFlags::REG_CLASS == 0)
            {{str}}.symTab.parent = {{symTab}}
            {{symTab}}.addEntry({{str}}.name,{{str}})
            {{str}}.flags |= ObjectFlags::REG_CLASS
        end
    end
    
    @[AlwaysInline]
    def self.lc_build_class(name : String)
        klass      = LcClass.new(name)
        klass.type = SType::CLASS
        return klass
    end

    @[AlwaysInline]
    def self.lc_build_class(name : String,path : Path)
        klass       = LcClass.new(name,path)
        klass.type  = SType::CLASS
        klass.klass = Lc_Class
        return klass
    end

    @[AlwaysInline]
    def self.lc_build_internal_class(name : String,parent : LcClass? = Obj)
        klass               = lc_build_class(name)
        klass.klass         = Lc_Class
        klass.symTab.parent = MainClass.symTab
        MainClass.symTab.addEntry(name,klass)
        lc_set_parent_class(klass,parent)
        return klass
    end

    def self.lc_build_unregistered_pyclass(name : String,obj : PyObject,parent : LcClass)
        gc_ref = PyGC.track(obj)
        stab   = HybridSymT.new(obj)
        smtab  = HybridSymT.new(obj)
        mtab   = HybridSymT.new(obj)
        klass  = LcClass.new(name,stab,Data.new,mtab,smtab)
        klass.gc_ref = gc_ref
        klass.type   = SType::PyCLASS
        klass.klass  = Lc_Class
        lc_set_parent_class(klass,parent)
        return klass
    end

    def self.lc_build_pyclass(name : String,obj : PyObject)
        klass               = lc_build_unregistered_pyclass(name,obj,PyObjClass)
        klass.symTab.parent = MainClass.symTab
        MainClass.symTab.addEntry(name,klass)
        klass.flags |= ObjectFlags::REG_CLASS
        return klass
    end

    def self.lc_build_internal_class_in(name : String,nest : Structure,parent : LcClass? = nil)
        klass               = lc_build_class(name)
        klass.symTab.parent = nest.symTab
        klass.klass         = Lc_Class
        nest.symTab.addEntry(name,klass)
        lc_set_parent_class(klass,parent)
        return klass
    end

    @[AlwaysInline]
    def self.lc_set_parent_class(klass : LcClass,parent : LcClass)
        klass.parent = parent
    end

    @[AlwaysInline]
    def self.lc_add_method(receiver : Structure, name : String, method : LcMethod)
        receiver.methods.addEntry(name,method)
    end

    @[AlwaysInline]
    def self.lc_add_undef_method(receiver : Structure,name : String,method : LcMethod)
        receiver.methods.addEntry(name,method)
    end

    def self.lc_add_internal(receiver : Structure,name : String,proc : LcProc,arity : Intnum)
        m = define_method(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_add_internal_protected(receiver : Structure,name : String,proc : LcProc,arity : Intnum)
        m = define_protected_method(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_remove_internal(receiver : Structure,name : String)
        m = undef_method(name,receiver)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_add_static(receiver : Structure, name : String, proc : LcProc,arity : Intnum)
        m = define_static(name,receiver,proc,arity)
        receiver.statics.addEntry(name,m)
    end

    def self.lc_remove_static(receiver : Structure,name : String)
        m = undef_static(name,receiver)
        receiver.statics.addEntry(name,m)
    end

    def self.lc_class_add_method(receiver : Structure,name : String,proc : LcProc,arity : Intnum)
        lc_add_internal(receiver,name,proc,arity)
        lc_add_static(receiver,name,proc,arity)
    end

    def self.lc_define_const(str : Structure, name : String, const :  LcVal)
        centry = LcConst.new(name,const)
        str.symTab.addEntry(name,centry)
    end

    @[AlwaysInline]
    def self.lc_set_allocator(klass : LcClass,allocator : LcProc)
        klass.allocator = allocator 
    end

    @[AlwaysInline]
    def self.lc_undef_allocator(klass : LcClass)
        klass.allocator = Allocator::UNDEF 
    end

    def self.seek_const_in_scope(scp : SymTab_t,name : String) :  LcVal?
        const = scp.lookUp(name)
        const = unpack_const(const)
        if const
            check_pystructs2(scp,const)
            return const 
        end
        scp = scp.parent 
        while scp 
            const = scp.lookUp(name)
            const = unpack_const(const)
            if const
                check_pystructs2(scp,const)
                return const 
            end
            scp = scp.parent
        end 
        return nil
    end 

    def self.lc_seek_const(str : Structure, name : String)
        const = seek_const_in_scope(str.symTab,name)
        return const if const
        const  = str.as(LcClass).symTab.lookUp(name)
        const  = unpack_const(const)
        if const
            check_pystructs(str,const)
            return const
        end
        parent = parent_of(str)
         while parent
            const = parent.symTab.lookUp(name)
            const = unpack_const(const)
            if const
                check_pystructs(parent,const)
                return const
            end
            parent = parent_of(parent)
        end
        return nil
    end

    def self.unpack_const(const)
        if const.is_a? Structure
            return const 
        elsif const.is_a? LcConst
            return const.as(LcConst).val
        elsif const.is_a? PyObject
            if is_pycallable(const) && !is_pytype(const)
                pyobj_decref(const)
                return nil 
            end
            return build_pyobj(const)
        end
    end

    def self.lc_find_allocator(klass : LcClass)
        alloc = klass.allocator 
        return alloc if alloc
        klass = parent_of(klass)
        while klass
            alloc = klass.allocator 
            return alloc if alloc
            klass = parent_of(klass)
        end 
        return nil 
    end

    @[AlwaysInline]
    private def self.fetch_pystruct(name : String)
        name = "_#{name}"
        tmp = MainClass.symTab.lookUp(name)
        if !tmp || !(tmp.is_a? Structure)
            lc_bug("Previously declared Python Class/Module not found") 
            return Null
        end
        return tmp.as(Structure)
    end

    #########

    @[AlwaysInline]
    def self.lc_class_compare(klass1 :  LcVal, klass2 :  LcVal)
        path1 = path_of(klass1)
        path2 = path_of(klass2)
        if !path1.empty? && !path2.empty?
            return lcfalse unless path_of(klass1) == path_of(klass2)
        else
            return lcfalse unless class_name(klass1) == class_name(klass2)
        end
        return lctrue
    end

    def self.lc_is_a(obj :  LcVal, lcType :  LcVal)
        if !(lcType.is_a? Structure)
            lc_raise(LcArgumentError,"Argument must be a class or a module")
            return lcfalse
        end
        objClass = class_of(obj)
        while objClass
            return lctrue if lc_class_compare(objClass,lcType) == lctrue
            objClass = parent_of(objClass)
        end
        return lcfalse
    end

    is_a = LcProc.new do |args|
        next internal.lc_is_a(*args.as(T2))
    end

    @[AlwaysInline]
    def self.lc_class_class(obj :  LcVal)
        return class_of(obj)
    end

    class_class = LcProc.new do |args|
        next class_of(args.as(T1)[0])
    end


    def self.lc_class_eq(klass :  LcVal, other :  LcVal)
        return lcfalse unless klass.class == other.class 
        return lcfalse unless type_of(klass) == type_of(other)
        return lc_class_compare(klass,other)
    end

    class_eq = LcProc.new do |args|
        next internal.lc_class_eq(*args.as(T2))
    end

    def self.lc_class_ne(klass :  LcVal, other)
        return lc_bool_invert(lc_class_eq(klass,other))
    end

    class_ne = LcProc.new do |args|
        next internal.lc_class_ne(*args.as(T2))
    end

    def self.lc_class_defrost(klass :  LcVal)
        klass.flags &= ~ObjectFlags::FROZEN 
        return klass 
    end 

    class_defrost = LcProc.new do |args|
        klass = args.as(T1)[0]
        next lc_class_defrost(*lc_cast(args,T1))
    end

    class_inspect = LcProc.new do |args|
        tmp = String.build do |io|
            io << '"'
            klass = args.as(T1)[0].as(Structure)
            path  = path_of(klass)
            if !path.empty?
                io << path.to_s
            else
                io << klass.name 
            end
            io << '"'
        end
        next internal.build_string(tmp)
    end

    class_to_s = LcProc.new do |args|
        klass = args.as(T1)[0].as(Structure)
        path  = path_of(klass)
        if path.empty?
            name = klass.name 
        else
            name = path.to_s
        end
        next build_string(name)
    end

    def self.lc_class_rm_static_method(klass :  LcVal, name :  LcVal)
        sname = id2string(name)
        return lcfalse unless sname
        unless lc_obj_responds_to? klass,sname
            lc_raise(LcNoMethodError, "Can't find static method '%s' for %s" % {sname,lc_typeof(klass)})
            return lcfalse 
        else 
            lc_remove_static(klass.as(Structure),sname)
            return lctrue 
        end 
    end

    class_rm_static_method = LcProc.new do |args|
        next internal.lc_class_rm_static_method(*args.as(T2))
    end

    def self.lc_class_rm_instance_method(klass :  LcVal,name :  LcVal)
        sname = id2string(name)
        return lcfalse unless sname
        unless lc_obj_responds_to? klass,sname,false
            lc_raise(LcNoMethodError,"Can't find instance method '%s' for %s" % {sname,lc_typeof(klass)})
            return lcfalse 
        else 
            lc_remove_internal(klass.as(Structure),sname)
            return lctrue  
        end
    end

    class_rm_instance_method = LcProc.new do |args|
        next internal.lc_class_rm_instance_method(*args.as(T2))
    end

    def self.lc_class_rm_method(obj :  LcVal,name :  LcVal)
        if obj.is_a? Structure 
            return lc_class_rm_static_method(obj,name)
        else 
            return lc_class_rm_instance_method(class_of(obj),name)
        end 
    end

    class_rm_method = LcProc.new do |args|
        next internal.lc_class_rm_method(*args.as(T2))
    end

    def self.lc_class_delete_instance_method(klass :  LcVal,name :  LcVal)
        sname = id2string(name)
        return lcfalse unless sname
        klass = klass.as(Structure)
        if klass.methods.lookUp(sname)
            klass.methods.removeEntry(sname)
            return lctrue
        else 
            lc_raise(LcNoMethodError,"Instance method '%s' not defined in %s" % {sname,lc_typeof(klass)})
        end 
        return lcfalse 
    end

    class_delete_ins_method = LcProc.new do |args|
        next internal.lc_class_delete_instance_method(*args.as(T2))
    end

    def self.lc_class_delete_static_method(klass :  LcVal, name :  LcVal)
        sname = id2string(name)
        return lcfalse unless sname
        klass = klass.as(Structure)
        if klass.statics.lookUp(sname)
            klass.statics.removeEntry(sname)
            return lctrue
        else
            lc_raise(LcNoMethodError,"Static method '%s' not defined in %s" % {sname,lc_typeof(klass)})
        end 
        return lcfalse 
    end 

    class_delete_st_method = LcProc.new do |args|
        next internal.lc_class_delete_static_method(*args.as(T2))
    end

    def self.lc_class_delete_method(obj :  LcVal,name :  LcVal)
        if obj.is_a? Structure
            return lc_class_delete_static_method(obj,name)
        else
            return lc_class_delete_instance_method(class_of(obj),name)
        end
    end

    class_delete_method = LcProc.new do |args|
        next internal.lc_class_delete_method(*args.as(T2))
    end

    def self.lc_class_ancestors(klass :  LcVal)
        ary = build_ary_new
        while klass 
            lc_ary_push(ary,klass)
            klass = parent_of(klass)
        end
        return ary 
    end

    class_ancestors = LcProc.new do |args|
        next lc_class_ancestors(*args.as(T1))
    end

    def self.lc_class_parent(klass :  LcVal)
        s_klass = parent_of(klass)
        return s_klass if s_klass
        return Null 
    end

    class_parent = LcProc.new do |args|
        next lc_class_parent(*lc_cast(args,T1))
    end

    def self.alias_method_str(klass : Structure, m_name : String, new_name : String)
        method = seek_method(klass,m_name,true)
        if method.is_a? LcMethod
            lc_add_method(klass,new_name,method)
        elsif method == 2
            lc_raise(LcNoMethodError,"Cannot alias protected methods")
            return false
        else
            lc_raise(LcNoMethodError,convert(:no_method) % klass.name)
            return false
        end
        return true
    end

    def self.lc_alias_method(klass :  LcVal, name :  LcVal, new_name :  LcVal)
        name = id2string(name)
        return lcfalse unless name 
        new_name = id2string(new_name)
        return lcfalse unless new_name
        if klass.is_a? Structure
            return val2bool(alias_method_str(klass,name,new_name))
        else
            return val2bool(alias_method_str(class_of(klass),name,new_name))
        end
    end

    alias_m = LcProc.new do |args|
        next lc_alias_method(*lc_cast(args,T3))
    end

    def self.lc_get_static_method(str : Structure,name : String)
        method = seek_static_method(str,name)
        return nil unless method.is_a? LcMethod
        if method.type == LcMethodT::PYTHON
            method.needs_gc = false 
        end
        return method
    end

    def self.lc_get_instance_method(str : Structure,name : String)
        method = seek_method(str,name)
        return nil unless method.is_a? LcMethod 
        if method.type == LcMethodT::PYTHON
            p true;gets
            method.needs_gc = false 
        end
        return method
    end

    def self.lc_get_method(obj :  LcVal,name :  LcVal)
        name = id2string(name)
        return Null unless name 
        if obj.is_a? Structure
            method = lc_get_static_method(obj,name)
        else
            method = lc_get_instance_method(class_of(obj),name)
        end
        unless method 
            lc_raise(LcNoMethodError,"Undefined method `#{name}' for #{lc_typeof(obj)}")
            return Null 
        end
        return build_method(obj,method)
    end

    get_method = LcProc.new do |args|
        next lc_get_method(*lc_cast(args,T2))
    end

    def self.lc_instance_method(klass :  LcVal, name :  LcVal)
        name   = id2string(name)
        return Null unless name
        method = lc_get_instance_method(lc_cast(klass,Structure),name)
        unless method
            lc_raise(LcNoMethodError,"Undefined method `#{name}' for #{lc_typeof(klass)}")
            return Null 
        end
        return build_unbound_method(method)
    end

    get_imethod = LcProc.new do |args|
        next lc_instance_method(*lc_cast(args,T2))
    end


    MainClass      = lc_build_class("BaseClass")
    Lc_Class       = internal.lc_build_internal_class("Class",MainClass)
    Lc_Class.klass = Lc_Class

    # internal.lc_remove_static(Lc_Class,"new")

    internal.lc_add_static(Lc_Class,"==",   class_eq,         1)
    internal.lc_add_static(Lc_Class,"<>",   class_ne,         1)
    internal.lc_add_static(Lc_Class,"!=",   class_ne,         1)
    internal.lc_add_static(Lc_Class,"to_s", class_to_s,       0)
    internal.lc_add_static(Lc_Class,"name", class_to_s,       0)
    internal.lc_add_static(Lc_Class,"inspect",class_inspect,  0)
    internal.lc_add_static(Lc_Class,"defrost",class_defrost,  0)
    internal.lc_add_static(Lc_Class,"parent",class_parent,    0)
    internal.lc_add_static(Lc_Class,"remove_instance_method",class_rm_instance_method,  1)
    internal.lc_add_static(Lc_Class,"remove_static_method",class_rm_static_method,      1)
    internal.lc_add_static(Lc_Class,"delete_static_method",class_delete_st_method,      1)
    internal.lc_add_static(Lc_Class,"delete_instance_method",class_delete_ins_method,   1)
    internal.lc_add_static(Lc_Class,"instance_method",get_imethod,                      1)
    internal.lc_add_static(Lc_Class,"ancestors", class_ancestors,                       0)

    internal.lc_class_add_method(Lc_Class,"is_a?", is_a,                                1)
    internal.lc_class_add_method(Lc_Class,"class",class_class,                          0)
    internal.lc_class_add_method(Lc_Class,"remove_method",class_rm_method,              1)
    internal.lc_class_add_method(Lc_Class,"delete_method",class_delete_method,          1)
    internal.lc_class_add_method(Lc_Class,"alias",alias_m,                              2)
    internal.lc_class_add_method(Lc_Class,"method",get_method,                          1)

end
