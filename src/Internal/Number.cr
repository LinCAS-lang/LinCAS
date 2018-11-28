
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

    alias NumType = LcInt | LcFloat

    macro positive_num(v)
        ({{v}}.as(LcNum).val > 0)
    end

    macro num2num(v)
        {{v}}.as(LcNum).val 
    end

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
    protected def self.num_append(buffer : String_buffer,value :  LcVal)
        buffer_append(buffer,num2num(value).to_s)
    end

    @[AlwaysInline]
    protected def self.num_auto(value : Num)
        if value.is_a? Float 
            return num2float(value)
        end
        return num2int(value)
    end

    def self.build_number(klass :  LcVal)
        klass      = klass.as(LcClass)
        num        = Num_.new
        num.klass  = klass
        num.data   = klass.data.clone 
        num.flags |= ObjectFlags::FROZEN 
        return num.as( LcVal)
    end

    @[AlwaysInline]
    def self.lc_number_allocate(klass : LcVal)
        return build_number(klass)
    end

    @[AlwaysInline]
    def self.num_hash(n :  LcVal)
        return num2int(num2num(n).hash.to_i64)
    end



    def self.lc_num_coerce(v1 :  LcVal,v2 :  LcVal,method : String)
        if v1.is_a? NumType && v2.is_a? NumType
            v1 = num2float(num2num(v1).to_f)
            v2 = num2float(num2num(v2).to_f)
            Exec.lc_call_fun(v1,method,v2)
        else
            c = internal.coerce(v1,v2).as( LcVal)
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

    def self.lc_num_gr(n1 :  LcVal, n2 :  LcVal)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) > num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    def self.lc_num_sm(n1 :  LcVal, n2 :  LcVal)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) < num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    def self.lc_num_ge(n1 :  LcVal, n2 :  LcVal)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) >= num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    def self.lc_num_se(n1 :  LcVal, n2 :  LcVal)
        if n1.is_a? NumType && n2.is_a? NumType
            return val2bool(num2num(n1) <= num2num(n2))
        else 
            lc_raise(LcArgumentError,convert(:comparison_failed) % {lc_typeof(n1),lc_typeof(n2)})
        end
    end

    @[AlwaysInline]
    def self.lc_num_is_zero(num :  LcVal)
        return lcfalse unless num.is_a? NumType
        return val2bool(num2num(num) == 0)
    end

    def self.lc_num_coerce(n1 :  LcVal, n2 :  LcVal)
        tmp = num2int(0)
        v1  = lc_num_to_cr_f(n1)
        return tuple2array(tmp,tmp) unless v1
        v2  = lc_num_to_cr_f(n2)
        return tuple2array(tmp,tmp) unless v2
        return tuple2array(num2float(v2),num2float(v1))
    end

    

    def self.init_number
        @@lc_number = internal.lc_build_internal_class("Number")
        define_allocator(@@lc_number,lc_number_allocate)

        lc_remove_internal(@@lc_number,"defrost")

        define_method(@@lc_number,">",lc_num_gr,            1)
        define_method(@@lc_number,"<",lc_num_sm,            1)
        define_method(@@lc_number,">=",lc_num_ge,           1)
        define_method(@@lc_number,"<=",lc_num_se,           1)
        define_method(@@lc_number,"zero?",lc_num_is_zero,   0)
        define_method(@@lc_number,"coerce",lc_num_coerce,   1)
    end

    
end