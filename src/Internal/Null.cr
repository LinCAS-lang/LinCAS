
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

    struct LcNull < BaseS
    end

    def self.lc_build_null
        null  = lincas_obj_alloc LcNull, @@lc_null, @@lc_null.data.clone
        return lc_obj_freeze null
    end

    def self.lc_lazy_build_null
        null  = LcNull.new
        null.flags |= ObjectFlags::FROZEN
        return null.as( LcVal)
    end

    @[AlwaysInline]
    def self.lc_null_and(v1 :  LcVal, v2 :  LcVal)
        return v1
    end 

    @[AlwaysInline]
    def self.lc_null_or(v1 :  LcVal, v2 :  LcVal)
        return v2 
    end 

    @[AlwaysInline]
    def self.lc_null_not(v1 :  LcVal)
        return lctrue 
    end

    @[AlwaysInline]
    def self.lc_null_to_s(arg = Null)
        return build_string("")
    end

    @[AlwaysInline]
    def self.lc_null_eq(unused,value : LcVal)
        if value.is_a? LcNull
            return lctrue 
        end
        return lcfalse
    end

    @[AlwaysInline]
    def self.lc_null_ne(unused,value : LcVal)
        if value.is_a? LcNull
            return lcfalse
        end
        return lctrue
    end

    def self.init_null
    @@lc_null = internal.lc_build_internal_class("Null")
        lc_undef_allocator(@@lc_null)

        lc_remove_internal(@@lc_null,"defrost")

        add_method(@@lc_null,"&&",lc_null_and,      1)
        add_method(@@lc_null,"||",lc_null_or,       1)
        add_method(@@lc_null,"!",lc_null_not,       0)
        add_method(@@lc_null,"==",lc_null_eq,       1)
        add_method(@@lc_null,"!=",lc_null_ne,       1)
        add_method(@@lc_null,"to_s",lc_null_to_s,   0)
        alias_method_str(@@lc_null,"to_s","inspect"     )

        null_clone = LcProc.new do |args|
            next args.as(T1)[0]
        end

        lc_add_internal(@@lc_null,"clone",null_clone, 0)
        init_lazy_const(pointerof(Null),@@lc_null)
    end

    global Null = Internal.lc_lazy_build_null
    
end
