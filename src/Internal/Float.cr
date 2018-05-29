
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

    def self.lc_num_to_cr_f(num : Value)
        if num.is_a? LcInt
            return int2num(num).to_f
        elsif num.is_a? LcFloat
            return float2num(num).as(Floatnum)
        else
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(num)} into Float")
        end 
        return nil 
    end

    def self.float2cr(*values)
        tmp = [] of Float64 
        values.each do |v|
            val = lc_num_to_cr_i(v)
            return nil unless val 
            tmp << val.to_f32
        end
        return tmp 
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

    macro num2bigfloat(num)
        BigFloat.new({{num}})
    end

    macro bigf2flo64(num)
        ({{num}}.round(20)).to_f64
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
            return num2float(float2num(n1) + float2num(n2))
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
            return num2float(float2num(n1) - float2num(n2))
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
            return num2float(float2num(n1) * float2num(n2))
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
            return num2float(float2num(n1) ** float2num(n2))
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

    float_round = LcProc.new do |args|
        args = args.as(An)
        float = internal.lc_num_to_cr_f(args[0]).as(Floatnum)
        num   = args[1]? || 1
        unless num.is_a? Intnum 
            num = internal.lc_num_to_cr_i(num).as(Intnum)
        end
        next num2float(float.round(num.to_i64))
    end

    float_ceil = LcProc.new do |args|
        float = internal.lc_num_to_cr_f(*args.as(T1))
        if float.is_a? Float32
            next num2float(LibM.ceil_f32(float.as(Float32)))
        {% if flag?(:fast_math) %}
        else 
            next num2float(LibM.ceil_f64(float.as(Float64)))
        {% else %}
        elsif float.is_a? Float64
            next num2float(LibM.ceil_f64(float.as(Float64)))
        else
            next num2float(float.as(BigFloat).ceil)
        {% end %}
        end
    end

    float_floor = LcProc.new do |args|
        float = internal.lc_num_to_cr_f(*args.as(T1))
        if float.is_a? Float32 
            next num2float(LibM.floor_f32(float.as(Float32)))
        else 
            next num2float(LibM.floor_f64(float.as(Float64)))
        end
    end

    float_trunc = LcProc.new do |args|
        float = internal.lc_num_to_cr_f(*args.as(T1))
        if float.is_a? Float32 
            next num2float(LibM.trunc_f32(float.as(Float32)))
        else 
            next num2float(LibM.trunc_f64(float.as(Float64)))
        end
    end

    def self.lc_float_eq(n : Value, obj : Value)
        if obj.is_a? LcFloat
            return val2bool(float2num(n) == float2num(obj))
        else 
            return lc_compare(n,obj)
        end
    end

    float_eq = LcProc.new do |args|
        next internal.lc_float_eq(*args.as(T2))
    end

    FloatClass = internal.lc_build_internal_class("Float",NumClass)
    internal.lc_undef_allocator(FloatClass)

    internal.lc_add_internal(FloatClass,"+",float_sum,  1)
    internal.lc_add_internal(FloatClass,"-",float_sub,  1)
    internal.lc_add_internal(FloatClass,"*",float_mult, 1)
    internal.lc_add_internal(FloatClass,"\\",float_idiv,1)
    internal.lc_add_internal(FloatClass,"/",float_fdiv, 1)
    internal.lc_add_internal(FloatClass,"^",float_power,1)
    internal.lc_add_internal(FloatClass,"-@",float_invert, 0)
    internal.lc_add_internal(FloatClass,"to_s",float_to_s,     0)
    internal.lc_add_internal(FloatClass,"to_i",float_to_i,     0)
    internal.lc_add_internal(FloatClass,"to_f",float_to_f,     0)
    internal.lc_add_internal(FloatClass,"abs",float_abs,       0)
    internal.lc_add_internal(FloatClass,"round",float_round,  -1)
    internal.lc_add_internal(FloatClass,"floor",float_floor,   0)
    internal.lc_add_internal(FloatClass,"ceil",float_ceil,     0)
    internal.lc_add_internal(FloatClass,"trunc",float_trunc,   0)


    LcInfinity  =  num2float(Float64::INFINITY)
    LcNinfinity = num2float(-Float64::INFINITY)
    internal.lc_define_const(FloatClass,"INFINITY",LcInfinity)

    NanObj = num2float(Float64::NAN)
    internal.lc_define_const(FloatClass,"NAN",NanObj)
end
