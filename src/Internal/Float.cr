
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
    

    struct LcFloat < LcNum
        @val : Floatnum
        def initialize(@val)
        end
        getter val
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

    def self.lc_float_idiv(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2int((float2num(n1) / float2num(n2)).to_i)
        else
            return internal.lc_num_coerce(n1,n2,"\\")
        end
        # Should never get here
        return Null
    end

    def self.lc_float_fdiv(n1 : Value, n2 : Value)
        n1 = n1.as(LcFloat)
        if n2.is_a? LcFloat
            return num2float(n1.val / n2.as(LcFloat).val)
        else
            return internal.lc_num_coerce(n1,n2,"/")
        end
        # Should never get here
        return Null
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

    def self.lc_float_to_s(n : Value)
        return internal.build_string(float2num(n).to_s)
    end

    def self.lc_float_to_i(n : Value)
        return internal.num2int(float2num(n).to_i)
    end

    FloatClass = internal.lc_build_class_only("Float")
    internal.lc_set_parent_class(FloatClass,NumClass)

    internal.lc_add_internal(FloatClass,"+",:lc_float_sum,  1)
    internal.lc_add_internal(FloatClass,"-",:lc_float_sub,  1)
    internal.lc_add_internal(FloatClass,"*",:lc_float_mult, 1)
    internal.lc_add_internal(FloatClass,"\\",:lc_float_idiv,1)
    internal.lc_add_internal(FloatClass,"/",:lc_float_fdiv, 1)
    internal.lc_add_internal(FloatClass,"^",:lc_float_power,1)
    internal.lc_add_internal(FloatClass,"to_s",:lc_float_to_s,0)
    internal.lc_add_internal(FloatClass,"to_i",:lc_float_to_i,0)
end