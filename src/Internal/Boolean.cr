
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

    class LcBTrue  < BaseC
        def to_s 
            return "true"
        end
    end

    class LcBFalse  < BaseC 
        def to_s 
            return "false"
        end
    end

    alias LcBool = LcBTrue | LcBFalse

    @[AlwaysInline]
    def self.val2bool(value : Bool)
        return lctrue if value 
        return lcfalse 
    end

    @[AlwaysInline]
    def self.bool2val(value :  LcVal)
        return value == lctrue ? true : false
    end

    def self.build_true
        lcTrue = lincas_obj_alloc LcBTrue, @@lc_boolean
        set_flag lcTrue, FROZEN
        return lcTrue.as( LcVal)
    end

    def self.lazy_build_true
        lcTrue        = LcBTrue.new
        lcTrue.flags |= ObjectFlags::FROZEN
        return lcTrue.as( LcVal)
    end

    def self.build_false
        lcFalse = lincas_obj_alloc LcBFalse, @@lc_boolean
        set_flag lcFalse, FROZEN
        return lcFalse.as( LcVal)
    end

    def self.lazy_build_false
        lcFalse        = LcBFalse.new
        lcFalse.flags |= ObjectFlags::FROZEN
        return lcFalse.as( LcVal)
    end

    def self.lc_bool_invert(value)
        if value.is_a? LcBTrue
            return lcfalse
        elsif value.is_a? LcBFalse
            return lctrue
        else 
            #internal.raise()
            return Null
        end
    end

    def self.lc_bool_eq(val1, val2)
        return lctrue if val1 == val2
        return lcfalse
    end

    def self.lc_bool_gr(val1, val2)
        return lctrue if val1 == lctrue && val2 == lcfalse
        return lcfalse
    end 

    def self.lc_bool_sm(val1, val2)
        return lctrue if val1 == lcfalse && val2 == lctrue
        return lcfalse 
    end

    def self.lc_bool_ge(val1, val2)
        return internal.lc_bool_gr(val1,val2)
    end 

    def self.lc_bool_se(val1, val2)
        return internal.lc_bool_sm(val1,val2)
    end

    def self.lc_bool_ne(val1, val2)
        return internal.lc_bool_invert(
            internal.lc_bool_eq(val1,val2)
        )
    end

    def self.lc_bool_and(val1, val2)
        return lctrue if val1 == lctrue && val2 == lctrue
        return lcfalse
    end

    def self.lc_bool_or(val1, val2)
        return lctrue if val1 == lctrue || val2 == lctrue
        return lcfalse 
    end

    def self.init_boolean
        @@lc_boolean = internal.lc_build_internal_class("Boolean")
        lc_undef_allocator(@@lc_boolean)

        lc_remove_internal(@@lc_boolean,"defrost")

        add_method(@@lc_boolean,"!", lc_bool_invert,0)
        add_method(@@lc_boolean,"==",lc_bool_eq,    1)
        add_method(@@lc_boolean,"!=",lc_bool_ne,    1)
        add_method(@@lc_boolean,"&&",lc_bool_and,   1)
        add_method(@@lc_boolean,"||",lc_bool_or,    1)

        init_lazy_const(pointerof(LcTrue),@@lc_boolean)
        init_lazy_const(pointerof(LcFalse),@@lc_boolean)
    end

    global LcTrue  = Internal.lazy_build_true
    global LcFalse = Internal.lazy_build_false

end
