
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

require "./Number"
module LinCAS::Internal

    def self.lc_num_to_cr_f(num :  LcVal)
        if num.is_a? LcInt
            return int2num(num).to_f
        elsif num.is_a? LcFloat
            return float2num(num).as(Floatnum)
        else
            lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof(num)} into Float")
        end 
        return nil 
    end

    def self.float2cr(*values)
        tmp = [] of Float64 
        values.each do |v|
            val = lc_num_to_cr_i(v)
            return nil unless val 
            tmp << val.to_f64
        end
        return tmp 
    end

    
    class LcFloat < LcNum
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
    def self.float2num(float :  LcVal)
        return float.as(LcFloat).val 
    end

    def self.build_float(num : Floatnum)
        flo       = lincas_obj_alloc LcFloat,@@lc_float, num
        return lc_obj_freeze(flo)
    end

    def self.lc_float_sum(n1 :  LcVal, n2 :  LcVal)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(float2num(n1) + float2num(n2))
        else
            return internal.lc_num_coerce(n1,n2,"+")
        end
    end

    def self.lc_float_sub(n1 :  LcVal, n2 :  LcVal)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(float2num(n1) - float2num(n2))
        else
            return internal.lc_num_coerce(n1,n2,"-")
        end
        # Should never get here
        return Null
    end

    def self.lc_float_mult(n1 :  LcVal, n2 :  LcVal)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(float2num(n1) * float2num(n2))
        else
            return internal.lc_num_coerce(n1,n2,"*")
        end
        # Should never get here
        return Null
    end

    def self.lc_float_idiv(n1 :  LcVal, n2 :  LcVal)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            if float2num(n2) == 0
                lc_raise(lc_zerodiv_err,"(Division by 0)")
                return positive_num(n1) ? @@lc_infinity : @@lc_ninfinity
            end
            return num2int((float2num(n1) / float2num(n2)).to_i)
        else
            return internal.lc_num_coerce(n1,n2,"\\")
        end
        # Should never get here
        return Null
    end

    def self.lc_float_fdiv(n1 :  LcVal, n2 :  LcVal)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val / float2num(n2))
        else
            return internal.lc_num_coerce(n1,n2,"/")
        end
        # Should never get here
        return Null
    end

    def self.lc_float_power(n1 :  LcVal, n2 :  LcVal)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(float2num(n1) ** float2num(n2))
        else
            return internal.lc_num_coerce(n1,n2,"**")
        end
        # Should never get here
        return Null
    end

    def self.lc_float_invert(n :  LcVal)
        return internal.build_float(- float2num(n))
    end

    def self.lc_float_to_s(n :  LcVal)
        return internal.build_string(float2num(n).to_s)
    end

    def self.lc_float_to_i(n :  LcVal)
        return internal.num2int(float2num(n).to_i)
    end

    @[AlwaysInline]
    def self.lc_float_abs(n : LcVal)
        val = internal.lc_num_to_cr_f(n)
        return Null unless val 
        return num2float(val.abs)
    end

    def self.lc_float_round(flo : LcVal, argv : LcVal)
        argv  = argv.as(Ary)
        float = float2num(flo)
        num   = argv.empty? ? 1 : argv[0]
        unless num.is_a? Intnum 
            num = internal.lc_num_to_cr_i(num)
        end
        return Null unless num
        return num2float(float.round(num.to_i64))
    end

    def self.lc_float_ceil(float : LcVal)
        if float.is_a? Float32
            return num2float(LibM.ceil_f32(float.as(Float32)))
        {% if flag?(:fast_math) %}
        else 
            return num2float(LibM.ceil_f64(float.as(Float64)))
        {% else %}
        elsif float.is_a? Float64
            return num2float(LibM.ceil_f64(float.as(Float64)))
        else
            return num2float(float.as(BigFloat).ceil)
        {% end %}
        end
        # Unreachable. For inference only
        Null
    end

    @[AlwaysInline]
    def self.lc_float_floor(n : LcVal)
        float = lc_num_to_cr_f(n)
        if float.is_a? Float32 
            return num2float(LibM.floor_f32(float.as(Float32)))
        else 
            return num2float(LibM.floor_f64(float.as(Float64)))
        end
    end

    def self.lc_float_trunc(n : LcVal)
        float = internal.lc_num_to_cr_f(n)
        if float.is_a? Float32 
            return num2float(LibM.trunc_f32(float.as(Float32)))
        else 
            return num2float(LibM.trunc_f64(float.as(Float64)))
        end
    end

    def self.lc_float_eq(n :  LcVal, obj :  LcVal)
        if obj.is_a? LcFloat
            return val2bool(float2num(n) == float2num(obj))
        else 
            return lc_compare(n,obj)
        end
    end

    @@lc_infinity  = uninitialized LcVal
    @@lc_ninfinity = uninitialized LcVal
    @@lc_nanobj    = uninitialized LcVal

    def self.init_float

        @@lc_float = internal.lc_build_internal_class("Float",@@lc_number)
        lc_undef_allocator(@@lc_float)

        @@lc_infinity  = num2float(Float64::INFINITY)
        @@lc_ninfinity = num2float(-Float64::INFINITY)
        @@lc_nanobj    = num2float(Float64::NAN)
    
        define_method(@@lc_float,"+",lc_float_sum,         1)
        define_method(@@lc_float,"-",lc_float_sub,         1)
        define_method(@@lc_float,"*",lc_float_mult,        1)
        define_method(@@lc_float,"\\",lc_float_idiv,       1)
        define_method(@@lc_float,"/",lc_float_fdiv,        1)
        define_method(@@lc_float,"**",lc_float_power,      1)
        define_method(@@lc_float,"-@",lc_float_invert,     0)
        define_method(@@lc_float,"to_s",lc_float_to_s,     0)
        define_method(@@lc_float,"to_i",lc_float_to_i,     0)
        define_method(@@lc_float,"to_f",lc_obj_self,       0)
        define_method(@@lc_float,"abs",lc_float_abs,       0)
        define_method(@@lc_float,"round",lc_float_round,  -1)
        define_method(@@lc_float,"floor",lc_float_floor,   0)
        define_method(@@lc_float,"ceil",lc_float_ceil,     0)
        define_method(@@lc_float,"trunc",lc_float_trunc,   0)
    
        lc_define_const(@@lc_float,"INFINITY",@@lc_infinity)
        lc_define_const(@@lc_float,"NAN",@@lc_nanobj)
    end
end
