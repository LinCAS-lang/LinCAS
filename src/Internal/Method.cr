
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
        name, args : Node, owner : LinCAS::Structure, code : Node, arity : Intnum, visib : VoidVisib = VoidVisib::PUBLIC
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
        name,args : Node, owner : LinCAS::Structure, code : Node, arity : Intnum, visib : VoidVisib = VoidVisib::PUBLIC
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

    def self.seek_method(receiver, name)
        method    = receiver.methods.lookUp(name)
        prevScope = receiver.prevScope
        if method
            return method 
        elsif !prevScope
            return 0
        else 
            while prevScope
                method = prevScope.methods.lookUp(name).as(MethodEntry)
                if method
                    case method.visib 
                        when VoidVisib::PUBLIC
                            return method 
                        when VoidVisib::PROTECTED
                            return 1
                        when VoidVisib::PRIVATE 
                            return 2
                    end
                end 
                prevScope = prevScope.prevScope
            end
            return 0
        end
        # Should never get here
        return 0
    end

    def self.seek_static_method(receiver : Structure, name)
        method    = receiver.methods.lookUp(name)
        prevScope = receiver.prevScope
        if method
            return method 
        elsif !prevScope 
            return 0
        else 
            while prevScope
                method    = prevScope.methods.lookUp(name)
                return method if method 
                prevScope = prevScope.prevScope
            end
            return 0
        end
        # Should never get here
        return 0
    end

    macro internal_call(name,args,arity)
        {%  if arity == 0 %}
                call_internal({{name}},{{args}}[0])
        {%  elsif arity == 1 %}
                call_internal_1({{name}},{{args}})
        {%  elsif arity == 2 %}
                call_internal_2({{name}},{{args}})
        {%  else %}
                call_internal_n({{name}},{{args}})
        {%  end %}
    end

    macro call_internal(name,arg)
        internal.{{name.id}}({{arg}})
    end

    macro call_internal_1(name,arg)
        internal.{{name.id}}({{arg}}[0],{{arg}}[1])
    end 

    macro call_internal_2(name,args)
        internal.{{name.id}}({{arg[0]}},{{arg[1]}},{{arg[3]}})
    end 

    macro call_internal_n(name,args)
        call_internal({{name}},{{args}})
    end

end