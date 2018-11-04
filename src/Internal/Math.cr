
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
        private def self.lc_{{name.id}}(v : Value)
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
        private def self.lc_{{name.id}}(v : Value)
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
        private def self.lc_a{{name.id}}(v : Value)
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
        private def self.lc_a{{name.id}}(v : Value)
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
        private def self.lc_{{name.id}}_ary(v : Value)
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
        def self.lc_{{name.id}}_ary(a1 : Value, a2 : Value)
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
    m_cos = LcProc.new do |args|
        mfun cos
    end

    default_def sin, Sin
    m_sin = LcProc.new do |args|
        mfun sin
    end

    default_def tan, Tan
    m_tan = LcProc.new do |args|
        mfun tan
    end

    adef_with_block(cos, Acos) do 
        if val > 1
            lc_raise(LcMathError,"(Value out of domain)")
            return Null 
        end
    end
    m_acos = LcProc.new do |args|
        mfun acos      
    end

    adef_with_block(sin, Asin) do 
        if val > 1
            lc_raise(LcMathError,"(Value out of domain)")
            return Null 
        end
    end
    m_asin = LcProc.new do |args|
        mfun asin
    end

    default_adef tan, Atan
    m_atan = LcProc.new do |args|
        mfun atan
    end

    default_def sinh
    m_sinh = LcProc.new do |args|
        mfun sinh
    end

    default_def cosh
    m_cosh = LcProc.new do |args|
        mfun cosh
    end

    default_adef cosh
    m_acosh = LcProc.new do |args|
        mfun acosh
    end

    default_adef sinh
    m_asinh = LcProc.new do |args|
        mfun asinh
    end
    
    def self.lc_gamma(v : Value)
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null 
        end 
        return num2float(Math.gamma(val).to_f)
    end

    m_gamma = LcProc.new do |args|
        mfun gamma
    end

    default_def exp, Exp
    m_exp = LcProc.new do |args|
        mfun exp
    end
    
    def_with_block(log, Log) do 
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
    end
    m_log = LcProc.new do |args|
        mfun log
    end

    default_def tanh
    m_tanh = LcProc.new do |args|
        mfun tanh
    end

    adef_with_block(tanh) do
        if val.abs > 1
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
    end
    m_atanh = LcProc.new do |args|
        mfun atanh
    end

    def self.lc_atan2(v1 : Value, v2 : Value)
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

    m_atan2 = LcProc.new do |args|
        mfun2 atan2
    end

    def self.lc_sqrt(v : Value)
        return build_function(Sqrt.new(get_function(v))) if v.is_a? LcFunction
        return complex_sqrt(v) if v.is_a? LcCmx
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        if val < 0
            return complex_sqrt_num(val)
        end
        return num2float(Math.sqrt(val).to_f)
    end

    m_sqrt = LcProc.new do |args|
        mfun sqrt
    end

    def self.lc_cbrt(v : Value)
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        return num2float(Math.cbrt(val).to_f)
    end

    m_cbrt = LcProc.new do |args|
        mfun cbrt
    end

    def self.lc_nrt(v1 : Value,v2 : Value)
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

    m_nrt = LcProc.new do |args|
        mfun2 nrt
    end

    def self.lc_copysign(v1 : Value, v2 : Value)
        val1 = internal.lc_num_to_cr_f(v1)
        return Null unless val1
        val2 = internal.lc_num_to_cr_f(v2)
        return Null unless val2
        return num2float(Math.copysign(val1,val2).to_f)
    end

    m_copysign = LcProc.new do |args|
        mfun2 copysign
    end

    def self.lc_log10(v : Value)
        val = internal.lc_num_to_cr_f(v)
        return Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            return Null
        end
        return num2float(Math.log10(val).to_f)
    end

    m_log10 = LcProc.new do |args|
        mfun log10
    end

    def self.lc_hypot(v1 : Value, v2 : Value)
        val1 = internal.lc_num_to_cr_f(v1)
        return Null unless val1
        val2 = internal.lc_num_to_cr_f(v2)
        return Null unless val2
        return num2float(Math.hypot(val1,val2).to_f)
    end

    m_hypot = LcProc.new do |args|
        mfun2 hypot
    end

    MathM = internal.lc_build_internal_module("Math")
    
    internal.lc_module_add_internal(MathM,"cos",m_cos,    1)
    internal.lc_module_add_internal(MathM,"sin",m_sin,    1)
    internal.lc_module_add_internal(MathM,"acos",m_acos,  1)
    internal.lc_module_add_internal(MathM,"asin",m_asin,  1)
    internal.lc_module_add_internal(MathM,"tan",m_tan,    1)
    internal.lc_module_add_internal(MathM,"atan",m_atan,  1)
    internal.lc_module_add_internal(MathM,"cosh",m_cosh,  1)
    internal.lc_module_add_internal(MathM,"sinh",m_sinh,  1)
    internal.lc_module_add_internal(MathM,"asinh",m_asinh,1)
    internal.lc_module_add_internal(MathM,"acosh",m_acosh,1)
    internal.lc_module_add_internal(MathM,"gamma",m_gamma,1)
    internal.lc_module_add_internal(MathM,"exp",m_exp,    1)
    internal.lc_module_add_internal(MathM,"log",m_log,    1)
    internal.lc_module_add_internal(MathM,"tanh",m_tanh,  1)
    internal.lc_module_add_internal(MathM,"atanh",m_atanh,1)
    internal.lc_module_add_internal(MathM,"atan2",m_atan2,2)
    internal.lc_module_add_internal(MathM,"sqrt",m_sqrt,  1)
    internal.lc_module_add_internal(MathM,"cbrt",m_cbrt,  1)
    internal.lc_module_add_internal(MathM,"nrt",m_nrt,    2)
    internal.lc_module_add_internal(MathM,"copysign",m_copysign,2)
    internal.lc_module_add_internal(MathM,"log10",m_log10,1)
    internal.lc_module_add_internal(MathM,"hypot",m_hypot,2)


    internal.lc_define_const(MathM,"PI",num2float(Math::PI))
    internal.lc_define_const(MathM,"E",num2float(Math::E))

end
