
# Copyright (c) 2017 Massimiliano Dal Mas
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
    
    def self.lc_build_class_only(name)
        return Id_Tab.addClass(name,true)
    end

    def self.lc_build_class(name)
        return Id_Tab.addClass(name)
    end

    def self.lc_set_parent_class(klass : LinCAS::ClassEntry,parent : LinCAS::ClassEntry)
        # internal.lc_raise() unless klass.parent.nil?
        klass.parent = parent
    end

    def self.lc_add_method(receiver, name, method : LinCAS::MethodEntry)
        receiver.symTab.addEntry(name,method)
    end

    def self.lc_add_method_locally(name, method : LinCAS::MethodEntry)
        Id_Tab.addMethod(name,method)
    end

    def self.lc_add_internal(receiver,name,proc,arity)
        m = define_method(name,receiver,proc,arity)
        receiver.symTab.addEntry(name,m)
    end

    def self.lc_add_static(receiver,name,proc,arity)
        m = define_static(name,receiver,proc,arity)
        receiver.symTab.addEntry(name,m)
    end

    def self.lc_add_singleton(receiver, name, proc,arity)
        m = define_singleton(name,receiver,proc,arity)
        receiver.symTab.addEntry(name,m)
    end

    def self.lc_add_static_singleton(receiver, name, proc, arity)
        m = define_static_singleton(name,receiver,proc,arity)
        receiver.symTab.addEntry(name,m)
    end

    #########

    def self.lc_is_a(obj : Value, lcType)
        # internal.lc_raise() unless lcType.is_a? Structure
        
    end

    def self.lc_class_class(obj : Value)
        return LcClass  if obj.is_a? ClassEntry
        return LcModule if obj.is_a? ModuleEntry
        return obj_of(obj).klass
    end

    def self.lc_class_eq(klass : Structure, other)
        return lcfalse unless klass.class == other.class
        return lcfalse unless klass.path  == other.path 
        return lctrue
    end

    def self.lc_class_ne(klass : Structure, other)
        return internal.lc_bool_invert(
            internal.lc_class_eq(klass,other)
        )
    end

    klass = internal.lc_build_class_only("Class")

    internal.lc_add_internal(klass,"is_a", :lc_is_a       ,1)
    internal.lc_add_internal(klass,"class",:lc_class_class,0)
    internal.lc_add_internal(klass,"==",   :lc_class_eq,   1)
    internal.lc_add_internal(klass,"<>",   :lc_class_ne,   1)

    LcClass = klass

end