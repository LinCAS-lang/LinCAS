
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

    macro mfun(name)
        arg = args.as(T2)[1]
        next lc_{{name.id}}_ary(arg) if arg.is_a? LcArray
        next lc_{{name.id}}(arg)
    end

    macro mfun2(name)
        args = args.as(T3)
        arg1 = args[1]
        arg2 = args[2]
        if arg1.is_a? LcArray && arg2.is_a? LcArray
            next lc_{{name.id}}_ary(arg1,arg2)
        end
        next lc_{{name.id}}(arg1,arg2)
    end

    macro default_def(name,sym = nil)
        private def self.lc_{{name.id}}(v :  LcVal)
            {% if sym %}
                return build_function({{sym}}.create(get_function(v))) if v.is_a? LcFunction
            {% end %}
            return complex_{{name.id}}(v) if v.is_a? LcCmx
            val = internal.lc_num_to_cr_f(v)
            return Null unless val
            return num2float(Math.{{name.id}}(val).to_f)
        end
    end

    macro def_with_block(name, sym = nil)
        private def self.lc_{{name.id}}(v :  LcVal)
            {% if sym %}
                return build_function({{sym}}.create(get_function(v))) if v.is_a? LcFunction
            {% end %}
            return complex_{{name.id}}(v) if v.is_a? LcCmx
            val = internal.lc_num_to_cr_f(v)
            return Null unless val
            {{yield}}
            return num2float(Math.{{name.id}}(val).to_f)
        end
    end

    macro default_adef(name, sym = nil)
        private def self.lc_a{{name.id}}(v :  LcVal)
            {% if sym %}
                return build_function({{sym}}.create(get_function(v))) if v.is_a? LcFunction
            {% end %}
            return complex_arc{{name.id}}(v) if v.is_a? LcCmx
            val = internal.lc_num_to_cr_f(v)
            return Null unless val
            return num2float(Math.a{{name.id}}(val).to_f)
        end
    end

    macro adef_with_block(name, sym = nil)
        private def self.lc_a{{name.id}}(v :  LcVal)
            {% if sym %}
                return build_function({{sym}}.create(get_function(v))) if v.is_a? LcFunction
            {% end %}
            return complex_arc{{name.id}}(v) if v.is_a? LcCmx
            val = internal.lc_num_to_cr_f(v)
            return Null unless val
            {{yield}}
            return num2float(Math.a{{name.id}}(val).to_f)
        end
    end

    {% for name in %w|cos sin acos asin tan atan cosh sinh asinh acosh gamma
                    exp log tanh atanh sqrt cbrt log10 |%}
        private def self.lc_{{name.id}}_ary(v :  LcVal)
            new_ary = build_ary_new
            ary_iterate(v) do |obj|
                res = lc_{{name.id}}(obj)
                if test(res)
                    lc_ary_push(new_ary,res)
                else
                    return new_ary 
                end
            end
            return new_ary
        end
    {% end %}

    {% for name in %w|atan2 nrt copysign hypot| %}
        def self.lc_{{name.id}}_ary(a1 :  LcVal, a2 :  LcVal)
            if ary_size(a1) != ary_size(a2)
                lc_raise(LcArgumentError,"(Array size missmatch)")
                return Null 
            end
            new_ary = build_ary_new
            ary_iterate_with_index(a1) do |obj,i|
                tmp = lc_{{name.id}}(obj,ary_at_index(a2,i))
                if test(tmp)
                    lc_ary_push(new_ary,tmp)
                else
                    return new_ary
                end
            end
            return new_ary
        end
    {% end %}

   
    default_def cos, Cos

    default_def sin, Sin

    default_def tan, Tan

    adef_with_block(cos, Acos) do 
        if val > 1
            lc_raise(LcMathError,"(Value out of domain)")
            return Null 
        end
    end

    adef_with_block(sin, Asin) do 
        if val > 1
            lc_raise(LcMathError,"(Value out of domain)")
            return Null 
        end
    end

    default_adef tan, Atan

    default_def sinh

    default_def cosh

    default_adef cosh

    default_adef sinh
    
    def self.lc_gamma(v :  LcVal)
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null 
        end 
        return num2float(Math.gamma(val).to_f)
    end

    default_def exp, Exp
    
    def_with_block(log, Log) do 
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
    end

    default_def tanh

    adef_with_block(tanh) do
        if val.abs > 1
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
    end

    def self.lc_atan2(v1 :  LcVal, v2 :  LcVal)
        if v1.is_a? LcCmx && v2.is_a? LcCmx
             tmp = complex_div(v1,v2)
             return lc_atan(tmp)
        elsif v1.is_a? LcCmx || v2.is_a? LcCmx
            return complex_div_num(v1,v2) if v1.is_a? LcCmx
            return complex_div_num(v2,v1)
        else 
            val1 = internal.lc_num_to_cr_f(v1)
            val2 = internal.lc_num_to_cr_f(v2)
            return Null unless val1 && val2
            return num2float(Math.atan2(val1,val2).to_f)
        end
    end

    def self.lc_sqrt(v :  LcVal)
        return build_function(Sqrt.create(get_function(v))) if v.is_a? LcFunction
        return complex_sqrt(v) if v.is_a? LcCmx
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        if val < 0
            return complex_sqrt_num(val)
        end
        return num2float(Math.sqrt(val).to_f)
    end

    def self.lc_cbrt(v :  LcVal)
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        return num2float(Math.cbrt(val).to_f)
    end

    def self.lc_nrt(v1 :  LcVal,v2 :  LcVal)
        val1 = internal.lc_num_to_cr_i(v1)
        return Null unless val1
        val2 = internal.lc_num_to_cr_f(v2)
        return Null unless val2
        if val1.even? && val2 < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
        if val1.is_a? BigInt
            val1 = bigf2flo64(num2bigfloat(val1))
        else 
            val1 = val1.to_f
        end
        return num2float(val2 ** (1/val1.to_f))
    end

    def self.lc_copysign(v1 :  LcVal, v2 :  LcVal)
        val1 = internal.lc_num_to_cr_f(v1)
        return Null unless val1
        val2 = internal.lc_num_to_cr_f(v2)
        return Null unless val2
        return num2float(Math.copysign(val1,val2).to_f)
    end

    def self.lc_log10(v :  LcVal)
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
        return num2float(Math.log10(val).to_f)
    end

    def self.lc_hypot(v1 :  LcVal, v2 :  LcVal)
        val1 = internal.lc_num_to_cr_f(v1)
        return Null unless val1
        val2 = internal.lc_num_to_cr_f(v2)
        return Null unless val2
        return num2float(Math.hypot(val1,val2).to_f)
    end

    def self.init_math
        @@lc_math = internal.lc_build_internal_module("Math")
    
        lc_module_add_internal(@@lc_math,"cos",wrap(lc_cos,2),     1)
        lc_module_add_internal(@@lc_math,"sin", wrap(lc_sin,2),    1)
        lc_module_add_internal(@@lc_math,"acos", wrap(lc_acos,2),  1)
        lc_module_add_internal(@@lc_math,"asin", wrap(lc_asin,2),  1)
        lc_module_add_internal(@@lc_math,"tan", wrap(lc_tan,2),    1)
        lc_module_add_internal(@@lc_math,"atan", wrap(lc_atan,2),  1)
        lc_module_add_internal(@@lc_math,"cosh", wrap(lc_cosh,2),  1)
        lc_module_add_internal(@@lc_math,"sinh", wrap(lc_sinh,2),  1)
        lc_module_add_internal(@@lc_math,"asinh", wrap(lc_asinh,2),1)
        lc_module_add_internal(@@lc_math,"acosh", wrap(lc_acosh,2),1)
        lc_module_add_internal(@@lc_math,"gamma", wrap(lc_gamma,2),1)
        lc_module_add_internal(@@lc_math,"exp", wrap(lc_exp,2),    1)
        lc_module_add_internal(@@lc_math,"log", wrap(lc_log,2),    1)
        lc_module_add_internal(@@lc_math,"tanh", wrap(lc_tanh,2),  1)
        lc_module_add_internal(@@lc_math,"atanh", wrap(lc_atanh,2),1)
        lc_module_add_internal(@@lc_math,"atan2", wrap(lc_atan2,3),2)
        lc_module_add_internal(@@lc_math,"sqrt", wrap(lc_sqrt,2),  1)
        lc_module_add_internal(@@lc_math,"cbrt", wrap(lc_cbrt,2),  1)
        lc_module_add_internal(@@lc_math,"nrt", wrap(lc_nrt,3),    2)
        lc_module_add_internal(@@lc_math,"copysign",wrap(lc_copysign,3),2)
        lc_module_add_internal(@@lc_math,"log10", wrap(lc_log10,2),1)
        lc_module_add_internal(@@lc_math,"hypot", wrap(lc_hypot,3),2)


        lc_define_const(@@lc_math,"PI",num2float(Math::PI))
        lc_define_const(@@lc_math,"E",num2float(Math::E))
    end

end
