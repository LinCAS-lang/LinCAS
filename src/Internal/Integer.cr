
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

    struct LcInt < LcNum
        @val : Intnum
        def initialize(@val)
        end
        getter val
    end

    macro num2bigint(num)
        BigInt.new({{num}})
    end

    macro big_int_power(v1,v2)
        #lc_warn()
        if {{v2}} < 0
            return 0
        end 
        return Float64::INFINITY
    end

    @[AlwaysInline]
    def self.num2int(num : Intnum)
        return build_int(num)
    end

    @[AlwaysInline]
    def self.int2num(int :  LcVal)
        return int.as(LcInt).val
    end 

    def self.lc_num_to_cr_i(value)
        if value.is_a? LcInt
            return value.as(LcInt).val
        elsif value.is_a? LcFloat
            return value.as(LcFloat).val.to_i
        else
            lc_raise(LcTypeError,"No implicit conversion of %s into Integer" % lc_typeof(value))
            return nil 
        end
    end

    def self.build_int(value : Intnum)
        int    = lincas_obj_alloc LcInt, @@lc_integer, value, data: @@lc_integer.data.clone
        int.id = (value * 2 + 1).to_u64
        return lc_obj_freeze(int)
    end 

    def self.build_fake_int(value : IntnumR)
        int = lincas_obj_alloc_fake LcInt, @@lc_integer, value
        int.id    = (value * 2 + 1).to_u64
        return lc_obj_freeze(int)
    end

    private def self.int_plus_int(n1 :  LcVal,n2 :  LcVal)
        v1 = int2num(n1)
        v2 = int2num(n2)
        if v1.is_a? BigInt && v2.is_a? BigInt
            return v1 + v2
        end
        if v1.is_a? BigInt || v2.is_a? BigInt
            return v1.to_big_i + v2.to_big_i
        end
        if v1.is_a? Int32 && v2.is_a? Int32
            if libc.add_overflow_i(v1,v2,out tmp1) == 0
                return v1 + v2
            end
            return  v1.to_i64 + v2.to_i64
        else
            v1  = v1.to_i64
            v2  = v2.to_i64
            if libc.add_overflow_l(v1,v2,out tmp) == 0
                return v1 + v2
            end
            return  num2bigint(v1) + num2bigint(v2)
        end
    end

    def self.lc_int_sum(n1 :  LcVal, n2 :  LcVal)
        if n2.is_a? LcInt 
            {% if flag?(:fast_math) %}
                return num2int(int2num(n1) + int2num(n2))
            {% else %}
                return num2int(int_plus_int(n1,n2))
            {% end %}
        else
            return lc_num_coerce(n1,n2,"+")
        end
        # Should never get here
        return Null
    end

    private def self.int_sub_int(n1 :  LcVal, n2 :  LcVal)
        v1 = int2num(n1)
        v2 = int2num(n2)
        if v1.is_a? BigInt && v2.is_a? BigInt
            return v1 - v2
        end
        if v1.is_a? Int32 && v2.is_a? Int32
            if libc.sub_overflow_i(v1,v2,out tmp) == 0
                return v1 - v2
            end 
            return v1.to_i64 - v2.to_i64
        else
            v1   = v1.to_i64
            v2   = v2.to_i64
            if libc.sub_overflow_l(v1,v2,out tmp2) == 0
                return v1 - v2
            end
            return num2bigint(v1) - num2bigint(v2)
        end
    end

    def self.lc_int_sub(n1 :  LcVal, n2 :  LcVal)
        if n2.is_a? LcInt 
            {% if flag?(:fast_math) %}
                return num2int(int2num(n1) - int2num(n2))
            {% else %}
                return num2int(int_sub_int(n1,n2))
            {% end %}
        else
            return lc_num_coerce(n1,n2,"-")
        end
        # Should never get here
        return Null
    end

    private def self.int_mult_int(n1 :  LcVal, n2 :  LcVal)
        v1 = int2num(n1)
        v2 = int2num(n2)
        if v1.is_a? BigInt && v2.is_a? BigInt
            return v1 * v2 
        end
        if v1.is_a? BigInt || v2.is_a? BigInt
            return v1.to_big_i * v2.to_big_i 
        end
        if v1.is_a? Int32 && v2.is_a? Int32
            if libc.mul_overflow_i(v1,v2,out tmp) == 0
                return v1 * v2 
            end
            return v1.to_i64 * v2.to_i64 
        else 
            v1 = v1.to_i64
            v2 = v2.to_i64
            if libc.mul_overflow_l(v1,v2,out tmp2) == 0
                return v1 * v2 
            end
            return v1.to_big_i * v2.to_big_i 
        end
    end

    def self.lc_int_mult(n1 :  LcVal, n2 :  LcVal)
        if n2.is_a? LcInt 
            {% if flag?(:fast_math) %}
                return num2int(int2num(n1) * int2num(n2))
            {% else %}
                return num2int(int_mult_int(n1,n2))
            {% end %}
        else
            return internal.lc_num_coerce(n1,n2,"*")
        end
        # Should never get here
        return Null
    end

    private def self.int_idiv_int(n1 :  LcVal,n2 :  LcVal)
        v1 = int2num(n1)
        v2 = int2num(n2)
        if v1.is_a? BigInt && v2.is_a? BigInt
            return v1 / v2 
        end
        if !(v1.is_a? BigInt || v2.is_a? BigInt)
            return v1.as(IntnumR) / v2.as(IntnumR)
        end
        return v1.to_big_i / v1.to_big_i
    end

    def self.lc_int_idiv(n1 :  LcVal, n2 :  LcVal)
        if n2.is_a? LcInt 
            if int2num(n2) == 0
                lc_raise(LcZeroDivisionError,"(Division by 0)")
                return positive_num(n1) ? @@lc_infinity : @@lc_ninfinity
            end
            {% if flag?(:fast_math) %}
                return num2int(int2num(n1) / int2num(n2))
            {% else %}
                return num2int(int_idiv_int(n1,n2))
            {% end %}
        else
            return internal.lc_num_coerce(n1,n2,"\\")
        end
        # Should never get here
        return Null
    end

    private def self.int_fdiv_int(n1 :  LcVal, n2 :  LcVal)
        v1 = int2num(n1)
        v2 = int2num(n2)
        if !(v1.is_a? BigInt || v2.is_a? BigInt)
            return v1.as(IntnumR) / v2.as(IntnumR).to_f
        end
        if v1.is_a? BigInt && v2.is_a? BigInt
            return bigf2flo64(v1.to_big_f / v2.to_big_f)
        end
        if v1.is_a? BigInt
            return bigf2flo64(v1.to_big_f / v2.as(IntnumR).to_big_f)
        end
        return bigf2flo64(num2bigfloat(v1.as(IntnumR)) / v2.to_big_f)
    end

    def self.lc_int_fdiv(n1 :  LcVal, n2 :  LcVal)
        if n2.is_a? LcInt 
            if int2num(n1) == 0
                return positive_num(n1) ? @@lc_infinity : @@lc_ninfinity
            end
            {% if flag?(:fast_math) %}
                return num2float(int2num(n1) / int2num(n2).to_f)
            {% else %}
                return num2float(int_fdiv_int(n1,n2))
            {% end %}
        else
            return internal.lc_num_coerce(n1,n2,"/")
        end
        # Should never get here
        return Null
    end

    private def self.int_power_int(n1 :  LcVal, n2 :  LcVal)
        v1 = int2num(n1)
        v2 = int2num(n2)
        if v1.is_a? BigInt && v2.is_a? BigInt
            big_int_power(v1,v2)
        end 
        if !(v1.is_a? BigInt || v2.is_a? BigInt)
            if v2 < 0
                return v1.to_f64 ** v2.as(IntnumR)
            else
                return v1.as(IntnumR) ** v2.as(IntnumR) 
            end
        end
        v1 = v1.to_big_i
        v2 = v2.to_big_i
        big_int_power(v1,v2)
    end

    def self.lc_int_power(n1 :  LcVal, n2 :  LcVal)
        if n2.is_a? LcInt 
            {% if flag?(:fast_math) %}
                exp = int2num(n2)
                if exp < 0
                    return num2int(int2num(n1).to_f ** int2num(n2))
                else
                    return num2int(int2num(n1) ** int2num(n2))
                end
            {% else %}
                val = int_power_int(n1,n2)
                if val.is_a? Floatnum
                    return num2float(val)
                end
                return num2int(val)
            {% end %}
        else
            return internal.lc_num_coerce(n1,n2,"**")
        end
        # Should never get here
        return Null
    end

    def self.lc_int_odd(n :  LcVal)
        if int2num(n).odd? 
            return lctrue
        else 
            return lcfalse
        end 
    end

    @[AlwaysInline]
    def self.lc_int_even(n :  LcVal)
        return internal.lc_bool_invert(lc_int_odd(n))
    end

    @[AlwaysInline]
    def self.lc_int_to_s(n :  LcVal)
        return internal.build_string(int2num(n).to_s)
    end

    def self.lc_int_to_f(n :  LcVal)
        val = int2num(n)
        if val.is_a? BigInt
            return num2float(bigf2flo64(val.to_big_f))
        end
        return internal.num2float(val.to_f)
    end

    def self.lc_int_invert(n :  LcVal)
        return internal.build_int(- int2num(n))
    end

    def self.lc_int_times(n :  LcVal)
        val = int2num(n)
        val.times do |i|
            Exec.lc_yield(num2int(i))
        end
        return Null
    end

    @[AlwaysInline]
    def self.lc_int_abs(n : LcVal)
        val = int2num(n)
        return Null unless val 
        return num2int(val.abs)
    end

    def self.lc_int_eq(n :  LcVal, obj :  LcVal)
        if obj.is_a? LcInt
            return val2bool(int2num(n) == int2num(obj))
        else 
            return lc_compare(n,obj)
        end
    end

    
    def self.init_integer
        @@lc_integer = internal.lc_build_internal_class("Integer",@@lc_number)
        lc_undef_allocator(@@lc_integer)
    
        add_method(@@lc_integer,"+",lc_int_sum,         1)
        add_method(@@lc_integer,"-",lc_int_sub,         1)
        add_method(@@lc_integer,"*",lc_int_mult,        1)
        add_method(@@lc_integer,"\\",lc_int_idiv,       1)
        add_method(@@lc_integer,"/",lc_int_fdiv,        1)
        add_method(@@lc_integer,"**",lc_int_power,      1)
        add_method(@@lc_integer,"==",lc_int_eq,         1)
        add_method(@@lc_number,"odd?",lc_int_odd,          0)
        add_method(@@lc_number,"even?",lc_int_even,        0)
        add_method(@@lc_integer,"-@",lc_int_invert,     0)
        add_method(@@lc_integer,"to_s",lc_int_to_s,     0)
        add_method(@@lc_integer,"to_f",lc_int_to_f,     0)

        int_to_i = LcProc.new do |args|
            next args.as(T1)[0]
        end

        add_method(@@lc_integer,"to_i",lc_obj_self,        0)
        add_method(@@lc_integer,"times",lc_int_times,   0)
        add_method(@@lc_integer,"abs",lc_int_abs,       0)

        int_hash = LcProc.new do |args|
            next num_hash(*lc_cast(args,T1))
        end

        lc_add_internal(@@lc_integer,"hash",int_hash,     0)
    end
    
end
