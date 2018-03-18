
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

    m_cos = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.cos(val).to_f)
    end

    m_sin = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.sin(val).to_f)
    end

    m_tan = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.tan(val).to_f)
    end

    m_acos = LcProc.new do |args|
        arg = args.as(T2)[1]
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
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.atan(val).to_f) 
    end

    m_sinh = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.sinh(val).to_f)
    end

    m_cosh = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.cosh(val).to_f)
    end

    m_acosh = LcProc.new do |args|
        arg = args.as(T2)[1]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.acosh(val).to_f)
    end

    m_asinh = LcProc.new do |args|
        arg = args.as(T2)[1]
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
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.exp(val).to_f)
    end

    m_log = LcProc.new do |args|
        arg = args.as(T2)[1]
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
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        next num2float(Math.tanh(val).to_f)
    end

    m_atanh = LcProc.new do |args|
        arg = args.as(T2)[1]
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
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val
        if val < 0
            lc_raise(LcMathError,"(Value out of domain)")
            next Null
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
        next num2float(val2 ** (1/val1.to_f))
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