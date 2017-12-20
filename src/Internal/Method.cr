
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
    
    def 
    self.lc_define_usr_method(
        name, args : Node, owner : LinCAS::Structure, code : Node, arity, visib : VoidVisib = VoidVisib::PUBLIC
    )
        m       = LinCAS::MethodEntry.new(name,visib)
        m.args  = args
        m.owner = owner
        m.code  = code
        m.arity = arity
        return m 
    end

    def 
    self.lc_define_static_usr_method(
        name,args : Node, owner : LinCAS::Structure, code : Node, arity, visib : VoidVisib = VoidVisib::PUBLIC
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

    macro define_method(name,owner,code,arity)
        internal.lc_define_internal_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro define_static(name,owner,code,arity)
        internal.lc_define_internal_static_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro define_singleton(name,owner,code,arity)
        internal.lc_define_internal_singleton_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    macro define_static_singleton(name,owner,code,arity)
        internal.lc_define_internal_static_singleton_method(
            {{name}},{{owner}},{{code}},{{arity}}
        )
    end

    def self.seek_method(entry : Structure, name)
        method    = entry.methods.lookUp(name)
        prevScope = entry.prevScope
        if method
            return method 
        elsif !prevScope
            return nil
        else 
            return self.seek_method(prevScope,name)
        end
    end

end