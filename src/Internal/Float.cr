
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

    def self.lc_num_to_cr_f(num : Value)
        if num.is_a? LcNum 
            return num2num(num).to_f
        else
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(num)} into Float")
        end 
        return nil 
    end
    

    struct LcFloat < LcNum
        @val : Floatnum
        def initialize(@val)
        end
        getter val
        def to_s 
            return @val.to_s 
        end
    end
    
    @[AlwaysInline]
    def self.num2float(num : Floatnum)
        return build_float(num)
    end

    @[AlwaysInline]
    def self.float2num(float : Value)
        return float.as(LcFloat).val 
    end

    def self.build_float(num : Floatnum)
        flo       = LcFloat.new(num)
        flo.klass = FloatClass
        flo.data  = FloatClass.data.clone
        flo.frozen = true
        return flo
    end

    def self.lc_float_sum(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val + n2.as(LcFloat).val)
        else
            return internal.lc_num_coerce(n1,n2,"+")
        end
    end

    float_sum = LcProc.new do |args|
        next internal.lc_float_sum(*args.as(T2))
    end

    def self.lc_float_sub(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val - n2.as(LcFloat).val)
        else
            return internal.lc_num_coerce(n1,n2,"-")
        end
        # Should never get here
        return Null
    end

    float_sub = LcProc.new do |args|
        next internal.lc_float_sub(*args.as(T2))
    end

    def self.lc_float_mult(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val * n2.as(LcFloat).val)
        else
            return internal.lc_num_coerce(n1,n2,"*")
        end
        # Should never get here
        return Null
    end

    float_mult = LcProc.new do |args|
        next internal.lc_float_mult(*args.as(T2))
    end

    def self.lc_float_idiv(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            if float2num(n2) == 0
                lc_raise(LcZeroDivisionError,"(Division by 0)")
                return positive_num(n1) ? LcInfinity : LcNinfinity
            end
            return num2int((float2num(n1) / float2num(n2)).to_i)
        else
            return internal.lc_num_coerce(n1,n2,"\\")
        end
        # Should never get here
        return Null
    end

    float_idiv = LcProc.new do |args|
        next internal.lc_float_idiv(*args.as(T2))
    end

    def self.lc_float_fdiv(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val / float2num(n2))
        else
            return internal.lc_num_coerce(n1,n2,"/")
        end
        # Should never get here
        return Null
    end

    float_fdiv = LcProc.new do |args|
        next internal.lc_float_fdiv(*args.as(T2))
    end

    def self.lc_float_power(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val ** n2.as(LcFloat).val)
        else
            return internal.lc_num_coerce(n1,n2,"^")
        end
        # Should never get here
        return Null
    end

    float_power = LcProc.new do |args|
        next internal.lc_float_power(*args.as(T2))
    end

    def self.lc_float_invert(n : Value)
        return internal.build_float(- float2num(n))
    end

    float_invert = LcProc.new do |args|
        next internal.lc_float_invert(*args.as(T1))
    end

    def self.lc_float_to_s(n : Value)
        return internal.build_string(float2num(n).to_s)
    end

    float_to_s = LcProc.new do |args|
        next internal.lc_float_to_s(*args.as(T1))
    end

    def self.lc_float_to_i(n : Value)
        return internal.num2int(float2num(n).to_i)
    end

    float_to_i = LcProc.new do |args|
        next internal.lc_float_to_i(*args.as(T1))
    end

    float_to_f = LcProc.new do |args|
        next args.as(T1)[0]
    end

    float_abs = LcProc.new do |args|
        arg = args.as(T1)[0]
        val = internal.lc_num_to_cr_f(arg)
        next Null unless val 
        next num2float(val.abs)
    end

    FloatClass = internal.lc_build_class_only("Float")
    internal.lc_set_parent_class(FloatClass,NumClass)

    internal.lc_add_internal(FloatClass,"+",float_sum,  1)
    internal.lc_add_internal(FloatClass,"-",float_sub,  1)
    internal.lc_add_internal(FloatClass,"*",float_mult, 1)
    internal.lc_add_internal(FloatClass,"\\",float_idiv,1)
    internal.lc_add_internal(FloatClass,"/",float_fdiv, 1)
    internal.lc_add_internal(FloatClass,"^",float_power,1)
    internal.lc_add_internal(FloatClass,"invert",float_invert, 0)
    internal.lc_add_internal(FloatClass,"to_s",float_to_s,     0)
    internal.lc_add_internal(FloatClass,"to_i",float_to_i,     0)
    internal.lc_add_internal(FloatClass,"to_f",float_to_f,     0)
    internal.lc_add_internal(FloatClass,"abs",float_abs,       0)


    LcInfinity  =  num2float(Float64::INFINITY)
    LcNinfinity = num2float(-Float64::INFINITY)
    internal.lc_define_const(FloatClass,"INFINITY",LcInfinity)

    NanObj = num2float(Float64::NAN)
    internal.lc_define_const(FloatClass,"NAN",NanObj)
end