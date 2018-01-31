
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
       {{klass}}.as(ClassEntry).parent
    end
    
    def self.lc_build_class_only(name : String)
        return Id_Tab.addClass(name,true)
    end

    def self.lc_build_class(name : String)
        return Id_Tab.addClass(name)
    end

    def self.lc_set_parent_class(klass : ClassEntry,parent : ClassEntry)
        klass.parent = parent
    end

    def self.lc_add_method(receiver : Structure, name : String, method : MethodEntry)
        receiver.methods.addEntry(name,method)
    end

    def self.lc_add_method_locally(name : String, method : LinCAS::MethodEntry)
        Id_Tab.addMethod(name,method)
    end

    def self.lc_add_internal(receiver : Structure,name : String,proc : LcProc,arity : Intnum)
        m = define_method(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_add_static(receiver : Structure, name : String, proc : LcProc,arity : Intnum)
        m = define_static(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_add_singleton(receiver : Structure, name : String, proc : LcProc,arity : Intnum)
        m = define_singleton(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_add_static_singleton(receiver : Structure, name : String, proc : LcProc, arity : Intnum)
        m = define_static_singleton(name,receiver,proc,arity)
        receiver.methods.addEntry(name,m)
    end

    def self.lc_define_const(str : Structure, name : String, const : Value)
        centry = ConstEntry.new(name,const)
        str.symTab.addEntry(name,centry)
    end

    def self.lc_define_const_locally(name : String, const : Value)
        Id_Tab.addConst(name,const)
    end

    def self.lc_copy_consts_in(sender : Structure, receiver : Structure)
        stab = sender.symTab
        rtab = receiver.symTab
        stab.each_key do |name|
            entry = stab.lookUp(name)
            if entry.is_a? ConstEntry
                rtab.addEntry(name,entry)
            end
        end
    end

    def self.lc_seek_const(str : Structure, name : String)
        const = Id_Tab.lookUp(name)
        return unpack_const(const) if const 
        if str.is_a? ModuleEntry
            return str.as(ModuleEntry).symTab.lookUp(name)
        else
            const = str.as(ClassEntry).symTab.lookUp(name)
            return unpack_const(const) if const 
            parent = parent_of(str)
            while parent
                const = parent.symTab.lookUp(name)
                return unpack_const(const) if const
                parent = parent_of(parent)
            end
        end
        return nil
    end

    def self.unpack_const(const)
        if const.is_a? Structure
            return const 
        else
            return const.as(ConstEntry).val
        end
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
                    return lctrue if parent.as(ClassEntry).path == lcType.path 
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
        return LcClass  if obj.is_a? ClassEntry
        return LcModule if obj.is_a? ModuleEntry
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

    LcClass = internal.lc_build_class_only("Class")

    internal.lc_add_internal(LcClass,"is_a", is_a,     1)
    internal.lc_add_internal(LcClass,"its_class",class_class,0)
    internal.lc_add_static(LcClass,"==",   class_eq,   1)
    internal.lc_add_static(LcClass,"<>",   class_ne,   1)
    internal.lc_add_static(LcClass,"!=",   class_ne,   1)
    internal.lc_add_static(LcClass,"defrost",class_defrost,  0)

end