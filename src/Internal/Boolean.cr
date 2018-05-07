
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

    struct LcBTrue  < BaseS
        def to_s 
            return "true"
        end
    end

    struct LcBFalse  < BaseS 
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
    def self.bool2val(value : Value)
        return value == lctrue ? true : false
    end

    def self.build_true
        lcTrue       = LcBTrue.new
        klass         = BoolClass
        lcTrue.klass  = klass.as(LcClass)
        lcTrue.data   = klass.as(LcClass).data.clone
        lcTrue.frozen = true
        return lcTrue.as(Value)
    end

    def self.build_false
        lcFalse        = LcBFalse.new
        klass          = BoolClass
        lcFalse.klass  = klass.as(LcClass)
        lcFalse.data   = klass.as(LcClass).data.clone
        lcFalse.frozen = true
        return lcFalse.as(Value)
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

    bool_invert = LcProc.new do |args|
        args = args.as(T1)
        next internal.lc_bool_invert(args[0])
    end

    def self.lc_bool_eq(val1, val2)
        return lctrue if val1 == val2
        return lcfalse
    end

    bool_eq = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_bool_eq(args[0],args[1])
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

    bool_ne = LcProc.new do |args|
        next internal.lc_bool_ne(*args.as(T2))
    end

    def self.lc_bool_and(val1, val2)
        return lctrue if val1 == lctrue && val2 == lctrue
        return lcfalse
    end

    bool_and = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_bool_and(args[0],args[1])
    end

    def self.lc_bool_or(val1, val2)
        return lctrue if val1 == lctrue || val2 == lctrue
        return lcfalse 
    end

    bool_or = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_bool_or(args[0],args[1])
    end

    BoolClass = internal.lc_build_internal_class("Boolean")
    internal.lc_undef_allocator(BoolClass)

    internal.lc_remove_internal(BoolClass,"defrost")

    internal.lc_add_internal(BoolClass,"!", bool_invert,0)
    internal.lc_add_internal(BoolClass,"==",bool_eq,    1)
    internal.lc_add_internal(BoolClass,"!=",bool_ne,    1)
    internal.lc_add_internal(BoolClass,"&&",bool_and,   1)
    internal.lc_add_internal(BoolClass,"||",bool_or,    1)

    LcTrue  = internal.build_true
    LcFalse = internal.build_false

end
