
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

    macro check_fun(f,ret = true)
        if !({{f}}.is_a? LcFunction)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{f}})} into Function")
            {% if ret %}
                return Null 
            {% else %}
                next Null 
            {% end %}
        end
    end

    macro ensure_var(var)
        if !(get_function({{var}}).is_a? Variable)
            lc_raise(LcTypeError,"Argument must be Variable, not #{lc_typeof({{var}})}")
            return Null 
        end
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
            elsif el.is_a? LcNum
                tmp << Snumber.new(num2num(el).as(IntnumR))
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

    {% for name in %w|sum sub prod div power|%}
        def self.lc_func_{{name.id}}(f1 : Value, f2 : Value)
            check_fun(f2)
            return build_function(s_{{name.id}}(get_function(f1),get_function(f2)))
        end
    {% end %}

    func_sum = LcProc.new do |args|
        next lc_func_sum(*lc_cast(args,T2))
    end

    func_sub = LcProc.new do |args|
        next lc_func_sub(*lc_cast(args,T2))
    end

    func_prod = LcProc.new do |args|
        next lc_func_prod(*lc_cast(args,T2))
    end

    func_div = LcProc.new do |args|
        next lc_func_div(*lc_cast(args,T2))
    end

    func_power = LcProc.new do |args|
        next lc_func_power(*lc_cast(args,T2))
    end

    def self.lc_func_uminus(f : Value)
        return build_function(-get_function(f))
    end

    func_uminus = LcProc.new do |args|
        next lc_func_uminus(*lc_cast(args,T1))
    end

    def self.lc_func_diff(f : Value, var : Value)
        check_fun(var)
        ensure_var(var)
        func = get_function(f)
        v    = get_function(var)
        return build_function(func.diff(v))
    end

    func_diff = LcProc.new do |args|
        next lc_func_diff(*lc_cast(args,T2))
    end

    def self.lc_func_eval(f : Value, dict : Value)
        hash_check(dict)
        tmp = get_function(f).eval(lc_cast(dict,LcHash))
        if tmp.is_a? Float 
            return num2float(tmp)
        else
            return num2int(tmp)
        end
    end

    func_eval = LcProc.new do |args|
        next lc_func_eval(*lc_cast(args,T2))
    end

    def self.lc_func_params(f : Value)
        func = get_function(f)
        tmp  = [] of Variable
        ary  = build_ary_new
        func.get_params(tmp)
        tmp.each do |param|
            lc_ary_push(ary,build_function(param))
        end
        return ary 
    end

    func_params = LcProc.new do |args|
        next lc_func_params(*lc_cast(args,T1))
    end

    FunctionClass = internal.lc_build_internal_class("Function")
    internal.lc_set_parent_class(FunctionClass,Obj)

    internal.lc_set_allocator(FunctionClass,function_allocator)

    internal.lc_add_internal(FunctionClass,"to_s",func_to_s,     0)
    internal.lc_add_internal(FunctionClass,"inspect",func_to_s,  0)
    internal.lc_add_internal(FunctionClass,"+",func_sum,         1)
    internal.lc_add_internal(FunctionClass,"-",func_sub,         1)
    internal.lc_add_internal(FunctionClass,"*",func_prod,        1)
    internal.lc_add_internal(FunctionClass,"/",func_div,         1)
    internal.lc_add_internal(FunctionClass,"\\",func_div,        1)
    internal.lc_add_internal(FunctionClass,"^",func_power,       1)
    internal.lc_add_internal(FunctionClass,"-@",func_power,      0)
    internal.lc_add_internal(FunctionClass,"diff",func_diff,     1)
    internal.lc_add_internal(FunctionClass,"eval",func_eval,     1)
    internal.lc_add_internal(FunctionClass,"params",func_params, 0)

    

    
    
end