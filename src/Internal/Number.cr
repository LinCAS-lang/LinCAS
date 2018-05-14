
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
<<<<<<< HEAD
    
    def self.lc_num_to_cr_i(value)
        if value.is_a? LcInt
            return value.as(LcInt).val
        elsif value.is_a? LcFloat
            return value.as(LcFloat).val.to_i
        else
            lc_raise(LcTypeError,"No implicit conversion of %s into Integer" % lc_typeof(value))
            return nil 
        end
=======

    macro check_num(v)
        if !({{v}}.is_a? LcNum)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{v}})} into Number")
            return Null 
        end
    end

    abstract struct LcNum < BaseS
    end

    struct Num_ < LcNum
        @val = 0.as(Num)
        property val 
    end

    @[AlwaysInline]
    protected def self.num_append(buffer : String_buffer,value : Value)
        buffer_append(buffer,num2num(value).to_s)
    end

    @[AlwaysInline]
    protected def self.num_auto(value : Num)
        if value.is_a? Float 
            return num2float(value)
        end
        return num2int(value)
    end

    def self.new_number(klass : Value)
        klass      = klass.as(LcClass)
        num        = Num_.new
        num.klass  = klass
        num.data   = klass.data.clone 
        num.frozen = true 
        return num.as(Value)
>>>>>>> lc-vm
    end

    abstract struct LcNum < BaseS
    end


    def self.lc_num_coerce(v1 : Value,v2 : Value,method : String)
        if v1.is_a? LcNum && v2.is_a? LcNum
            v1 = internal.num2float(v1.as(LcNum).val.to_f)
            v2 = internal.num2float(v2.as(LcNum).val.to_f)
            Exec.lc_call_fun(v1,method,v2)
        else
            c = internal.coerce(v1,v2).as(Value)
            return Null if c == Null
            return Exec.lc_call_fun(
                internal.lc_ary_index(c,num2int(0)),
                method,
                internal.lc_ary_index(c,num2int(1))
            )
        end 
    end

    def self.lc_num_eq(n1 : Value, n2 : Value)
        if n2.is_a? LcNum
            if num2num(n1) == num2num(n2)
                return lctrue
            else 
                return lcfalse
            end
        else 
            return lc_num_coerce(n1,n2,"==")
        end
    end

    num_eq = LcProc.new do |args|
        next internal.lc_num_eq(*args.as(T2))
    end

    def self.lc_num_gr(n1 : Value, n2 : Value)
        if n2.is_a? LcNum
            if num2num(n1) > num2num(n2)
                return lctrue
            else 
                return lcfalse
            end
        else 
            return lc_num_coerce(n1,n2,">")
        end
    end

    num_gr = LcProc.new do |args|
        next internal.lc_num_gr(*args.as(T2))
    end

    def self.lc_num_sm(n1 : Value, n2 : Value)
        if n2.is_a? LcNum
            if num2num(n1) < num2num(n2)
                return lctrue
            else 
                return lcfalse
            end
        else 
            return lc_num_coerce(n1,n2,"<")
        end
    end

    num_sm = LcProc.new do |args|
        next internal.lc_num_sm(*args.as(T2))
    end

    def self.lc_num_ge(n1 : Value, n2 : Value)
        if n2.is_a? LcNum
            if num2num(n1) >= num2num(n2)
                return lctrue
            else 
                return lcfalse
            end
        else 
            return lc_num_coerce(n1,n2,">=")
        end
    end

    num_ge = LcProc.new do |args|
        next internal.lc_num_ge(*args.as(T2))
    end

    def self.lc_num_se(n1 : Value, n2 : Value)
        if n2.is_a? LcNum
            if num2num(n1) <= num2num(n2)
                return lctrue
            else 
                return lcfalse
            end
        else 
            return lc_num_coerce(n1,n2,"<=")
        end
    end

    num_se = LcProc.new do |args|
        next internal.lc_num_se(*args.as(T2))
    end

    num_ne = LcProc.new do |args|
        next internal.lc_bool_invert(internal.lc_num_eq(*args.as(T2)))
    end
    


<<<<<<< HEAD
    NumClass = internal.lc_build_class_only("Number")
    internal.lc_set_parent_class(NumClass,Obj)
=======
    NumClass = internal.lc_build_internal_class("Number")
    internal.lc_set_allocator(NumClass,number_allocator)
>>>>>>> lc-vm

    internal.lc_remove_static(NumClass,"new")
    internal.lc_remove_internal(NumClass,"defrost")

    internal.lc_add_internal(NumClass,"==",num_eq, 1)
    internal.lc_add_internal(NumClass,"!=",num_ne, 1)
    internal.lc_add_internal(NumClass,">",num_gr,  1)
    internal.lc_add_internal(NumClass,"<",num_sm,  1)
    internal.lc_add_internal(NumClass,">=",num_ge, 1)
    internal.lc_add_internal(NumClass,"<=",num_se, 1)

    
end