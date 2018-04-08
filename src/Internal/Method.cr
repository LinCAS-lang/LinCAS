
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

    EMPTY_CODE = Parser::NOOP

     private def self.lc_undef_method(name,owner : Structure)
        m       = LinCAS::MethodEntry.new(name.as(String),VoidVisib::UNDEFINED)
        m.args  = EMPTY_CODE 
        m.code  = EMPTY_CODE
        m.arity = 0
        m.owner = owner
        return m
    end
    
    def 
    self.lc_define_usr_method(
        name, args : Node, owner : LinCAS::Structure, code : Node,
        arity : Intnum, visib : VoidVisib = VoidVisib::PUBLIC
    )
        m       = LinCAS::MethodEntry.new(name.as(String),visib)
        m.args  = args
        m.owner = owner
        m.code  = code
        m.arity = arity
        return m 
    end

    def 
    self.lc_define_static_usr_method(
        name,args : Node, owner : LinCAS::Structure, code : Node, 
        arity : Intnum, visib : VoidVisib = VoidVisib::PUBLIC 
    )
        m        = self.lc_define_usr_method(name,args,owner,code,arity,visib)
        m.static = true
        return m
    end

    def self.lc_define_internal_method(name, owner : LinCAS::Structure, code, arity)
        m          = LinCAS::MethodEntry.new(name, VoidVisib::PUBLIC)
        m.internal = true
        m.owner    = owner
        m.code     = code
        m.arity    = arity 
        return m
    end

    def self.lc_define_internal_static_method(name, owner : LinCAS::Structure, code, arity)
        m        = self.lc_define_internal_method(name,owner,code,arity)
        m.static = true
        return m
    end

    def self.lc_define_internal_singleton_method(name,owner : LinCAS::Structure,code,arity)
        m           = self.lc_define_internal_method(name,owner,code,arity)
        m.singleton = true
        return m
    end

    def self.lc_define_internal_static_singleton_method(name,owner : LinCAS::Structure,code,arity)
        m           = self.lc_define_internal_static_method(name,owner,code,arity)
        m.singleton = true
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
        m.internal = true 
        return m
    end 

    def self.lc_undef_internal_static(name,owner : Structure)
        m = lc_undef_internal_method(name,owner)
        m.static = true 
        return m
    end
    
    def self.lc_undef_internal_singleton(name,owner : Structure)
        m = lc_undef_internal_method(name,owner)
        m.singleton = true 
        return m 
    end

    def self.lc_undef_internal_static_singleton(name,owner : Structure)
        m = lc_undef_internal_static(name,owner)
        m.singleton = true 
        return m 
    end

    macro define_method(name,owner,code,arity)
        internal.lc_define_internal_method(
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

    macro define_singleton(name,owner,code,arity)
        internal.lc_define_internal_singleton_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro undef_singleton(name,owner)
        internal.lc_undef_internal_singleton({{name}},{{owner}})
    end

    macro define_static_singleton(name,owner,code,arity)
        internal.lc_define_internal_static_singleton_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro undef_static_singleton(name,owner)
        internal.lc_undef_internal_static_singleton({{name}},{{owner}})
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
        method = receiver.methods.lookUp(name)
        if method.is_a? MethodEntry
            return method unless check
            method = method.as(MethodEntry)
            case method.visib 
                when VoidVisib::PUBLIC
                    return method
                when VoidVisib::PROTECTED
                    return method if protctd
                    return 1
                when VoidVisib::PRIVATE 
                    return 2
                when VoidVisib::UNDEFINED 
                    return 3
            end
        else
            return 0
        end
    end

    def self.seek_static_method(receiver : Structure, name)
        method    = seek_static_method2(receiver,name)
        return 0 if method == 1
        if method.is_a? MethodEntry
            return method
        else
            if receiver.is_a? ClassEntry
                parent = parent_of(receiver)
                while parent 
                    method = seek_static_method2(parent,name)
                    return 0 if method == 1
                    return method if method.is_a? MethodEntry
                    parent = parent_of(parent) 
                end
            end
        end
        return 0
    end
    
    def self.seek_static_method2(receiver : Structure, name : String)
        method = receiver.statics.lookUp(name)
        if !method.nil?
            method = method.as(MethodEntry)
            return 1 if method.visib == VoidVisib::UNDEFINED
            return method
        end
        return 0
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
        return m.is_a? MethodEntry
    end

    def self.lc_copy_methods_as_instance_in(sender : Structure, receiver : Structure)
        smtab = sender.methods
        rmtab = receiver.methods
        smtab.each_key do |name|
            method = smtab[name].as(MethodEntry)
            method.owner = receiver
            internal.insert_method_as_instance(method,rmtab)
        end
    end

    def self.lc_copy_methods_as_static_in(sender : Structure, receiver : Structure)
        smtab = sender.methods
        rmtab = receiver.statics
        smtab.each_key do |name|
            method = smtab[name].as(MethodEntry)
            method.owner = receiver
            internal.insert_method_as_static(method,rmtab)
        end
    end

    @[AlwaysInline]
    def self.insert_method_as_instance(method : MethodEntry, r : SymTab)
        r.addEntry(method.name,method)
    end

    def self.insert_method_as_static(method : MethodEntry, r : SymTab)
        method.static = true
        r.addEntry(method.name,method)
    end


end