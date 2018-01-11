
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

    macro positive_num(v)
        ({{v}}.as(LcNum).val > 0)
    end

    macro num2num(v)
        {{v}}.as(LcNum).val 
    end
    
    def self.lc_num_to_cr_i(value)
        if value.is_a? LcInt
            return value.as(LcInt).val
        elsif value.is_a? LcFloat
            return value.as(LcFloat).val.to_i
        else
            # internal.lc_raise()
        end
    end

    abstract struct LcNum < BaseS
    end

    struct Inf < BaseS
        @positive = true 
        attr positive
    end

    struct LcNan < BaseS
    end

    def self.lc_num_coerce(v1 : Value,v2 : Value,method : String)
        if v1.is_a? LcNum && v2.is_a? LcNum
            v1 = internal.build_float(v1.as(LcNum).val.to_f)
            v2 = internal.build_float(v2.as(LcNum).val.to_f)
            Exec.lc_call_fun(v1,method,v2)
        else
            c = internal.coerce(v1,v2).as(Value)
            return Null if c == Null
            return Exec.lc_call_fun(
                internal.lc_ary_index(c,internal.num2int(0)),
                method,
                internal.lc_ary_index(c,internal.num2int(1))
            )
        end 
    end

    NumClass = internal.lc_build_class_only("Number")
    internal.lc_set_parent_class(NumClass,LcClass)

    # Definition of Infinity:Class methods

    macro is_positive(v)
        ({{v}}.as(Inf).positive)
    end

    macro is_negative(v)
        !({{v}}.as(Inf).positive)
    end

    def self.build_infinity
        inf = Inf.new
        inf.klass = InfClass
        inf.data  = InfClass.data.clone
        inf.frozen = true
        return inf.as(Value)
    end
            
    def self.lc_inf_sum(v1 : Value, v2 : Value)
        v1 = v1.as(Inf)
        if v2.is_a? Inf
            if is_positive(v1) && is_positive(v2)
                return LcInfinity
            else
                return NanObj
            end
        elsif v2.is_a? LcNum
            return v1
        else
            return internal.lc_num_coerce(v1,v2,"+")
        end
    end

    def self.lc_inf_sub(v1 : Value, v2 : Value)
        if v2.is_a? Inf
            if is_negative(v1) && is_negative(v2)
                return LcNinfinity
            else
                return NanObj
            end
        elsif v2.is_a? LcNum
            return v1
        else
            return internal.lc_num_coerce(v1,v2,"-")
        end
    end

    def self.lc_inf_mult(v1 : Value, v2 : Value)
        if v2.is_a? Inf
            if is_negative(v1) || is_negative(v2)
                return LcNinfinity
            else
                return LcInfinity
            end
        elsif v2.is_a? LcNum
            return v1
        else
            return internal.lc_num_coerce(v1,v2,"*")
        end
    end

    def self.lc_inf_div(v1 : Value, v2 : Value)
        if v2.is_a? Inf
            return NanObj
        elsif v2.is_a? LcNum
            return v1 
        else 
            return internal.lc_num_coerce(v1,v2,"/")
        end
    end

    def self.lc_inf_power(v1 : Value, v2 : Value)
        if v2.is_a? Inf
            return NanObj
        elsif v2.is_a? LcNum
            if num2num == 0
                return NanObj
            else
                return v1
            end
        else 
            return internal.lc_num_coerce(v1,v2,"/")
        end
    end

    InfClass = internal.lc_build_class_only("Infinity")
    internal.lc_set_parent_class(InfClass,NumClass)
    internal.lc_add_internal(InfClass,"+",:lc_inf_sum, 1)
    internal.lc_add_internal(InfClass,"-",:lc_inf_sum, 1)
    internal.lc_add_internal(InfClass,"*",:lc_inf_mult,1)
    internal.lc_add_internal(InfClass,"/",:lc_inf_div, 1)
    internal.lc_add_internal(InfClass,"\\",:lc_inf_div,1)
    internal.lc_add_internal(InfClass,"^",:lc_inf_power,1)
    
    LcInfinity  = internal.build_infinity
    LcNinfinity = Inf.new.tap { |inf| inf.positive = false}
    internal.lc_define_const(NumClass,"Infinity",LcInfinity)
    
end