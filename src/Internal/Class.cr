
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

end