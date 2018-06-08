
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

    m_cos = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_cos(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.cos(val).to_f)
    end

    m_sin = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_sin(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.sin(val).to_f)
    end

    m_tan = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_tan(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.tan(val).to_f)
    end

    m_acos = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_arccos(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val > 1
            lc_raise(LcMathError,"(Value out of domain)")
            next Null 
        end 
        next num2float(Math.acos(val).to_f)       
    end

    m_asin = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_arcsin(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val > 1
            lc_raise(LcMathError,"(Value out of domain)")
            next Null 
        end 
        next num2float(Math.asin(val).to_f) 
    end

    m_atan = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_arctan(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.atan(val).to_f) 
    end

    m_sinh = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_sinh(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.sinh(val).to_f)
    end

    m_cosh = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_cosh(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.cosh(val).to_f)
    end

    m_acosh = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_arccosh(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.acosh(val).to_f)
    end

    m_asinh = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_arcsinh(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.asinh(val).to_f)
    end

    m_gamma = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            next Null 
        end 
        next num2float(Math.gamma(val).to_f)
    end

    m_exp = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_exp(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.exp(val).to_f)
    end

    m_log = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_log(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            next Null
        end
        next num2float(Math.log(val).to_f)
    end

    m_tanh = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_tanh(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.tanh(val).to_f)
    end

    m_atanh = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_arctanh(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val.abs > 1
            lc_raise(LcMathError,"(Value out of domain)")
            next Null
        end
        next num2float(Math.atanh(val).to_f)
    end

    m_atan2 = LcProc.new do |args|
        args = args.as(T3)
        arg1 = args[1]
        arg2 = args[2]
        val1 = internal.lc_num_to_cr_f(arg1)
        val2 = internal.lc_num_to_cr_f(arg2)
        next Null unless val1 && val2
        next num2float(Math.atan2(val1,val2).to_f)
    end

    m_sqrt = LcProc.new do |args|
        arg = args.as(T2)[1]
        next complex_sqrt(arg) if arg.is_a? LcCmx
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val < 0
            next complex_sqrt_num(val)
        end
        next num2float(Math.sqrt(val).to_f)
    end

    m_cbrt = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.cbrt(val).to_f)
    end

    m_nrt = LcProc.new do |args|
        args = args.as(T3)
        arg1 = args[1]
        arg2 = args[2]
        val1 = internal.lc_num_to_cr_i(arg1)
        val2 = internal.lc_num_to_cr_f(arg2)
        next Null unless val1 && val2
        if val1.even? && val2 < 0
            lc_raise(LcMathError,"(Value out of domain)")
            next Null
        end
        if val1.is_a? BigInt
            val1 = bigf2flo64(num2bigfloat(val1))
        else 
            val1 = val1.to_f
        end
        next num2float(val2 ** (1/val1))
    end

    m_copysign = LcProc.new do |args|
        args = args.as(T3)
        arg1 = args[1]
        arg2 = args[2]
        val1 = internal.lc_num_to_cr_f(arg1)
        val2 = internal.lc_num_to_cr_f(arg2)
        next Null unless val1 && val2
        next num2float(Math.copysign(val1,val2).to_f)
    end

    m_log10 = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            next Null
        end
        num2float(Math.log10(val).to_f)
    end

    m_hypot = LcProc.new do |args|
        args = args.as(T3)
        arg1 = args[1]
        arg2 = args[2]
        val1 = internal.lc_num_to_cr_f(arg1)
        val2 = internal.lc_num_to_cr_f(arg2)
        next Null unless val1 && val2
        num2float(Math.hypot(val1,val2).to_f)
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
