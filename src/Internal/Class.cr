
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal

    macro parent_of(klass)
       {{klass}}.as(LcClass).parent
    end

    macro class_of(obj)
        {{obj}}.as(ValueR).klass 
    end
    
    @[AlwaysInline]
    def self.lc_build_class(name : String)
        klass = LcClass.new(name)
    end

    @[AlwaysInline]
    def self.lc_build_class(name : String,path : Path)
        klass = LcClass.new(name,path)
    end

    @[AlwaysInline]
    def self.lc_build_internal_class(name : String)
        klass = lc_build_class(name,Path.new.forceAddName(name))
        klass.symTab.parent = MainClass.symTab
        MainClass.symTab.addEntry(name,klass)
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

    def self.lc_add_singleton(receiver : Structure, name : String, proc : LcProc,arity : Intnum)
        m = define_singleton(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_remove_singleton(receiver : Structure,name : String)
        m = undef_singleton(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_add_static_singleton(receiver : Structure, name : String, proc : LcProc, arity : Intnum)
        m = define_static_singleton(name,receiver,proc,arity)
        receiver.statics.addEntry(name,m)
    end

    def self.lc_remove_static_singleton(receiver : Structure,name : String)
        m = undef_static_singleton(receiver,name)
        receiver.statics.addEntry(name,m)
    end

    def self.lc_add_class_method(receiver : Structure,name : String,proc : LcProc,arity : Intnum)
        lc_add_internal(receiver,name,proc,arity)
        lc_add_static(receiver,name,proc,arity)
    end

    def self.lc_define_const(str : Structure, name : String, const : Value)
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

    #def self.lc_define_const_locally(name : String, const : Value)
    #    Id_Tab.addConst(name,const)
    #end

    def self.lc_copy_consts_in(sender : Structure, receiver : Structure)
        stab = sender.symTab
        rtab = receiver.symTab
        stab.each_key do |name|
            entry = stab.lookUp(name)
            if entry.is_a? LcConst
                rtab.addEntry(name,entry)
            end
        end
    end

    def self.seek_const_in_scope(scp : SymTab,name : String) : Value?
        const = scp.lookUp(name)
        return unpack_const(const).as(Value) if const
        scp = scp.parent 
        while scp 
            const = scp.lookUp(name)
            return unpack_const(const).as(Value) if const
            scp = scp.parent
        end 
        return nil
    end 

    def self.lc_seek_const(str : Structure, name : String)
        const = seek_const_in_scope(str.symTab,name)
        if const
            return const.as(Value)
        end
        if str.is_a? LcModule
            return str.as(LcModule).symTab.lookUp(name).as(Value?)
        else
            const = str.as(LcClass).symTab.lookUp(name)
            return unpack_const(const).as(Value) if const 
            parent = parent_of(str)
            while parent
                const = parent.symTab.lookUp(name)
                return unpack_const(const).as(Value) if const
                parent = parent_of(parent)
            end
        end
        return nil
    end

    def self.unpack_const(const)
        if const.is_a? Structure
            return const 
        else
            return const.as(LcConst).val
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

    #########

    def self.lc_is_a(obj : Value, lcType : Value)
        if lcType.is_a? Structure
            lcType = lcType.as(Structure)
        else
            lc_raise(LcArgumentError,"Argument must be a class or a module")
            return lcfalse
        end
        if obj.is_a? Structure
            return (obj.as(Structure).path == lcType.path) ? lctrue : lcfalse
        else
            objClass = obj.as(ValueR).klass
            if objClass.path == lcType.path
                return lctrue
            else
                parent = parent_of(objClass)
                while parent
                    return lctrue if parent.as(LcClass).path == lcType.path 
                    parent = parent_of(parent)
                end
            end
        end
        return lcfalse
    end

    is_a = LcProc.new do |args|
        next internal.lc_is_a(*args.as(T2))
    end

    def self.lc_class_class(obj : Value)
        return Lc_Class  if obj.is_a? LcClass
        #return LcModule if obj.is_a? ModuleEntry
        return obj.as(ValueR).klass
    end

    class_class = LcProc.new do |args|
        next internal.lc_class_class(*args.as(T1))
    end


    def self.lc_class_eq(klass : Value, other : Value)
        return lcfalse unless klass.class == other.class
        return lcfalse unless klass.as(Structure).path  == other.as(Structure).path 
        return lctrue
    end

    class_eq = LcProc.new do |args|
        next internal.lc_class_eq(*args.as(T2))
    end

    def self.lc_class_ne(klass : Value, other)
        return internal.lc_bool_invert(
            internal.lc_class_eq(klass,other)
        )
    end

    class_ne = LcProc.new do |args|
        next internal.lc_class_ne(*args.as(T2))
    end

    def self.lc_class_defrost(klass : Value)
        klass.frozen = false 
        return klass 
    end 

    class_defrost = LcProc.new do |args|
        klass = args.as(T1)[0]
        klass.frozen = false 
        next klass
    end

    class_to_s = LcProc.new do |args|
        tmp = String.build do |io|
            io << '"'
            io << args.as(T1)[0].as(Structure).path.to_s
            io << '"'
        end
        next internal.build_string(tmp)
    end

    def self.lc_class_rm_static_method(klass : Value, name : Value)
        sname = string2cr(name)
        return Null unless sname
        unless lc_obj_responds_to? klass,sname
            lc_raise(LcNoMethodError, "Can't find static method '%s' for %s" % {sname,lc_typeof(klass)})
            return Null 
        else 
            lc_remove_static(klass.as(Structure),sname)
            return Null 
        end 
    end

    class_rm_static_method = LcProc.new do |args|
        next internal.lc_class_rm_static_method(*args.as(T2))
    end

    def self.lc_class_rm_instance_method(klass : Value,name : Value)
        sname = string2cr(name)
        return Null unless sname
        unless lc_obj_responds_to? klass,sname,false
            lc_raise(LcNoMethodError,"Can't find instance method '%s' for %s" % {sname,lc_typeof(klass)})
            return Null 
        else 
            lc_remove_internal(klass.as(Structure),sname)
            return Null  
        end
    end

    class_rm_instance_method = LcProc.new do |args|
        next internal.lc_class_rm_instance_method(*args.as(T2))
    end

    def self.lc_class_rm_method(obj : Value,name : Value)
        if obj.is_a? Structure 
            return lc_class_rm_static_method(obj,name)
        else 
            return lc_class_rm_instance_method(class_of(obj),name)
        end 
    end

    class_rm_method = LcProc.new do |args|
        next internal.lc_class_rm_method(*args.as(T2))
    end

    def self.lc_class_delete_instance_method(klass : Value,name : Value)
        sname = string2cr(name)
        return Null unless sname
        klass = klass.as(Structure)
        if klass.methods.lookUp(sname)
            klass.methods.removeEntry(sname)
        else 
            lc_raise(LcNoMethodError,"Instance method '%s' not defined in %s" % {sname,lc_typeof(klass)})
        end 
        return Null 
    end

    class_delete_ins_method = LcProc.new do |args|
        next internal.lc_class_delete_instance_method(*args.as(T2))
    end

    def self.lc_class_delete_static_method(klass : Value, name : Value)
        sname = string2cr(name)
        return Null unless sname
        klass = klass.as(Structure)
        if klass.statics.lookUp(sname)
            klass.statics.removeEntry(sname)
        else
            lc_raise(LcNoMethodError,"Static method '%s' not defined in %s" % {sname,lc_typeof(klass)})
        end 
        return Null 
    end 

    class_delete_st_method = LcProc.new do |args|
        next internal.lc_class_delete_static_method(*args.as(T2))
    end

    def self.lc_class_delete_method(obj : Value,name : Value)
        if obj.is_a? Structure
            return lc_class_delete_static_method(obj,name)
        else
            return lc_class_delete_instance_method(class_of(obj),name)
        end
    end

    class_delete_method = LcProc.new do |args|
        next internal.lc_class_delete_method(*args.as(T2))
    end


    MainClass = lc_build_class("BaseClass")
    Lc_Class = internal.lc_build_internal_class("Class")
    internal.lc_set_parent_class(Lc_Class,MainClass)

    internal.lc_remove_static(Lc_Class,"new")

    internal.lc_add_internal(Lc_Class,"is_a?", is_a,          1)
    internal.lc_add_static(Lc_Class,"==",   class_eq,         1)
    internal.lc_add_static(Lc_Class,"<>",   class_ne,         1)
    internal.lc_add_static(Lc_Class,"!=",   class_ne,         1)
    internal.lc_add_static(Lc_Class,"to_s", class_to_s,       0)
    internal.lc_add_static(Lc_Class,"inspect",class_to_s,     0)
    internal.lc_add_static(Lc_Class,"defrost",class_defrost,  0)
    internal.lc_add_static(Lc_Class,"remove_instance_method",class_rm_instance_method,  1)
    internal.lc_add_static(Lc_Class,"remove_static_method",class_rm_static_method,      1)
    internal.lc_add_static(Lc_Class,"delete_static_method",class_delete_st_method,      1)
    internal.lc_add_static(Lc_Class,"delete_instance_method",class_delete_ins_method,   1)

    internal.lc_add_class_method(Lc_Class,"its_class",class_class,                      0)
    internal.lc_add_class_method(Lc_Class,"remove_method",class_rm_method,              1)
    internal.lc_add_class_method(Lc_Class,"delete_method",class_delete_method,          1)

end