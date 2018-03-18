
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

    alias NumType = LcInt | LcFloat

    macro positive_num(v)
        ({{v}}.as(LcNum).val > 0)
    end

    macro num2num(v)
        {{v}}.as(LcNum).val 
    end

    abstract struct LcNum < BaseS
    end

    struct Num_ < LcNum
        @val = 0.as(Num)
        property val 
    end

    def self.new_number(klass : Value)
        klass      = klass.as(LcClass)
        num        = Num_.new
        num.klass  = klass
        num.data   = klass.data.clone 
        num.frozen = true 
        return num.as(Value)
    end

    number_allocator = LcProc.new do |args|
        next internal.new_number(*args.as(T1))
    end


    def self.lc_num_coerce(v1 : Value,v2 : Value,method : String)
        if v1.is_a? NumType && v2.is_a? NumType
            v1 = num2float(num2num(v1).to_f)
            v2 = num2float(num2num(v2).to_f)
            Exec.lc_call_fun(v1,method,v2)
        else
            c = internal.coerce(v1,v2).as(Value)
            return Null if c == Null
            if !(c.is_a? LcArray)
                lc_raise(LcTypeError,"Coerce must return [x,y]")
                return Null 
            end
            if !(ary_size(c) == 2)
                lc_raise(LcTypeError,"Coerce must return [x,y]")
                return Null 
            end
            return Exec.lc_call_fun(
                lc_ary_index(c,num2int(0)),
                method,
                lc_ary_index(c,num2int(1))
            )
        end 
    end

    def self.lc_num_gr(n1 : Value, n2 : Value)
        if n1.class.is_a? NumType && n2.class.is_a? NumType
            return val2bool(num2num(n1) > num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    num_gr = LcProc.new do |args|
        next internal.lc_num_gr(*args.as(T2))
    end

    def self.lc_num_sm(n1 : Value, n2 : Value)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) < num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    num_sm = LcProc.new do |args|
        next internal.lc_num_sm(*args.as(T2))
    end

    def self.lc_num_ge(n1 : Value, n2 : Value)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) >= num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    num_ge = LcProc.new do |args|
        next internal.lc_num_ge(*args.as(T2))
    end

    def self.lc_num_se(n1 : Value, n2 : Value)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) <= num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    num_se = LcProc.new do |args|
        next internal.lc_num_se(*args.as(T2))
    end

    @[AlwaysInline]
    def self.lc_num_is_zero(num : Value)
        return lcfalse unless num.is_a? NumType
        return val2bool(num2num(num) == 0)
    end

    num_is_zero = LcProc.new do |args|
        next val2bool(num2num(args.as(T1)[0]) == 0)
    end

    def self.lc_num_coerce(n1 : Value, n2 : Value)
        tmp = num2int(0)
        v1  = lc_num_to_cr_f(n1)
        return tuple2array(tmp,tmp) unless v1
        v2  = lc_num_to_cr_f(n2)
        return tuple2array(tmp,tmp) unless v2
        return tuple2array(num2float(v2),num2float(v1))
    end

    num_coerce = LcProc.new do |args|
        next internal.lc_num_coerce(*args.as(T2))
    end

    


    NumClass = internal.lc_build_internal_class("Number")
    internal.lc_set_parent_class(NumClass,Obj)
    internal.lc_set_allocator(NumClass,number_allocator)

    internal.lc_remove_internal(NumClass,"defrost")

    internal.lc_add_internal(NumClass,">",num_gr,    1)
    internal.lc_add_internal(NumClass,"<",num_sm,    1)
    internal.lc_add_internal(NumClass,">=",num_ge,   1)
    internal.lc_add_internal(NumClass,"<=",num_se,   1)
    internal.lc_add_internal(NumClass,"zero?",num_is_zero,   0)
    internal.lc_add_internal(NumClass,"coerce",num_coerce,   1)

    
end