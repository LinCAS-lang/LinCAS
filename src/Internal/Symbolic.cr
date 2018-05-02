
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

    alias Symbolic_t = Symbolic | Value

    class LcFunction < BaseC
        @func : Symbolic = NanC
        property func
    end

    macro set_function(obj,func)
        lc_cast({{obj}},LcFunction).func = {{func}}
    end

    macro get_function(obj)
        lc_cast({{obj}},LcFunction).func
    end

    private def self.to_symbolic(*values) : Array(Symbolic)
        tmp = [] of Symbolic
        values.each do |el|
            if el.is_a? LcFunction
                tmp << el.func
            elsif el.is_a? Symbolic
                tmp << el
            else
                lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(el)} into Function")
                tmp << NanC
            end
        end
        return tmp
    end

    {% for block in { {"sum",'+'},{"sub",'-'},{"prod",'*'},{"div",'/'},{"power","**"} } %}
        def self.s_{{block[0].id}}(v1 : Symbolic_t,v2 : Symbolic_t)
            v1,v2 = to_symbolic(v1,v2)
            return v1 {{block[1].id}} v2
        end
    {% end %}

    def self.function_allocate(klass : LcClass)
        tmp = LcFunction.new
        tmp.klass = klass 
        tmp.data  = klass.data.clone 
        tmp.id    = tmp.object_id 
        return lc_cast(tmp,Value)
    end

    function_allocator = LcProc.new do |args|
        args = lc_cast(args,T1)
        next function_allocate(lc_cast(args[0],LcClass))
    end

    def self.build_function
        return function_allocate(FunctionClass)
    end

    def self.build_function(func : Symbolic)
        tmp = build_function
        set_function(tmp,func)
        return tmp
    end

    def self.lc_func_to_s(obj : Value)
        return build_string_recycle(get_function(obj).to_s.to_s)
    end

    func_to_s = LcProc.new do |args|
        next lc_func_to_s(*lc_cast(args,T1))
    end

    FunctionClass = internal.lc_build_internal_class("Function")
    internal.lc_set_parent_class(FunctionClass,Obj)

    internal.lc_set_allocator(FunctionClass,function_allocator)

    internal.lc_add_internal(FunctionClass,"to_s",func_to_s,     0)

    
    
end